module dpq2_serialization;

import std.stdio;
import std.traits;
import std.typecons;
import std.datetime;

import vibe.data.json;
import vibe.data.bson;
import dpq2;
import dpq2.conv.time: TimeStamp, TimeStampUTC, TimeOfDayWithTZ, Interval;

struct pgColumn
{
    string name;
}

string columnName(T, string member)()
{
    foreach(attr; __traits(getAttributes, __traits(getMember, T, member)))
    {
        if (is(typeof(attr) == pgColumn))
            return attr.name;
    }
    return member;
}

T to(T)(Row data)
{
    static if (is(T == struct))
        T res;
    else
        T res = new T;

    static foreach(memberName; __traits(allMembers, T))
    {
        // New scope to avoid already defined errors
        // when used variables during compile time
        {
            static if (memberName != "Monitor" && !isSomeFunction!(__traits(getMember, res, memberName)))
            {
                // PG column name same as memberName unless @pgColumn
                // attribute added to the member.
                enum name = columnName!(T, memberName);

                // Convert the PG type to this type
                enum type = typeof(__traits(getMember, res, memberName)).stringof;

                // Example conversion:
                // if (data.columnExists("column_name") && !data["column_name"].isNull)
                //     res.column_name = data["column_name"].as!<column_type>
                // if (data.columnExists(\"" ~ name ~ "\") && !data[\"" ~ name ~ "\"].isNull)
                mixin("
                if (data.columnExists(\"" ~ name ~ "\"))
                    res." ~ memberName ~ " = data[\"" ~ name ~ "\"].as!(" ~ type ~ ");
                ");
            }
        }
    }
    return res;
}
