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

struct pgType
{
    string name;
}

string columnName(T, string member)()
{
    static if (getUDAs!(__traits(getMember, T, member), pgColumn).length > 0)
        return getUDAs!(__traits(getMember, T, member), pgColumn)[0].name;

    return member;
}

string columnType(T, string member)()
{
    static if (getUDAs!(__traits(getMember, T, member), pgType).length > 0)
        return "PG" ~ getUDAs!(__traits(getMember, T, member), pgType)[0].name;

    return typeof(__traits(getMember, T, member)).stringof;
}

T deserializeTo(T)(Row data)
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
                enum type = columnType!(T, memberName);

                // Example conversion:
                // if (data.columnExists("column_name") && !data["column_name"].isNull)
                //     res.column_name = data["column_name"].as!<column_type>
                // if (data.columnExists(\"" ~ name ~ "\") && !data[\"" ~ name ~ "\"].isNull)
                mixin("
                if (data.columnExists(\"" ~ name ~ "\") && !data[\"" ~ name ~ "\"].isNull)
                    res." ~ memberName ~ " = data[\"" ~ name ~ "\"].as!(" ~ type ~ ");
                ");
            }
        }
    }
    return res;
}
