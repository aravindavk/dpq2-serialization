# Tiny library for dpq2 serialization

## Install

```
dub add dpq2-serialization
```

Postgresql types and D types:

```
Postgres Type          D Type
boolean                bool
smallint               short
integer                int
bigint                 long
real                   float
double_precision       double
text                   string
numeric                string
bytea                  immutable(ubyte)[]
uuid                   UUID
date                   Date
time_without_time_zone TimeOfDay       // import std.datetime : TimeOfDay;
time_with_time_zone    TimeOfDayWithTZ // import dpq2.conv.time: TimeOfDayWithTZ;
timestamp              TimeStamp       // import dpq2.conv.time: TimeStamp;
timestamptz            TimeStampUTC    // import dpq2.conv.time: TimeStampUTC;
interval               Interval        // import dpq2.conv.time: Interval;
json                   Json            // import vibe.data.json: Json;
bson                   Bson            // import vibe.data.json: Bson;
```

## Usage

Define the struct or class as required. For example, `User`

```d
struct User
{
    ulong id;
    string name;
    string email;
    @pgColumn("email_verified") bool emailVerified;
}
```

After running the query, convert the result `Row` to respective type.

```d
ulong userId = 1;
string query = "SELECT * FROM users WHERE id = $1";
QueryParams qps;
qps.sqlCommand = query;
qps.argsVariadic(userId);
auto rs = conn.execParams(qps);
auto user = rs[0].to!User;
```

## With Web frameworks

### With Handy-Httpd

```d
#!/usr/bin/env dub
/+ dub.sdl:
dependency "dpq2" version="~>1.1.7"
dependency "handy-httpd" version="~>8.4.0"
dependency "dpq2-serialization" path="../dpq2-serialization"
+/
import std.process;
import std.algorithm;
import std.range;

import handy_httpd;
import handy_httpd.handlers;
import vibe.data.json;
import dpq2;
import dpq2_serialization;

Connection conn;

// Create Db connection per worker thread
static this()
{
    conn = new Connection(environment["DATABASE_URL"]);
}

class User
{
    ulong id;
    string name;
    string email;
    @pgColumn("email_verified") bool emailVerified;
}

void listUsersHandler(ref HttpRequestContext ctx)
{
    string query = "SELECT * FROM users";
    QueryParams qps;
    qps.sqlCommand = query;
    auto rs = conn.execParams(qps);
    User[] users;
    foreach(idx; 0..rs.length)
        users ~= rs[idx].to!User;

    ctx.response.writeBodyString(serializeToJsonString(users));
}

void main()
{
    auto pathHandler = new PathHandler()
        .addMapping(Method.GET, "/api/v1/users", &listUsersHandler);
    new HttpServer(pathHandler).start();
}
```

### With Vibe.d

```d
#!/usr/bin/env dub
/+ dub.sdl:
dependency "vibe-http" version="~>1.1.0"
dependency "dpq2" version="~>1.1.7"
dependency "dpq2-serialization" path="../dpq2-serialization"
+/
import std.range;
import std.process;

import vibe.http.server;
import vibe.http.router;
import vibe.core.core : runApplication;
import vibe.data.json;
import dpq2;
import dpq2_serialization;

Connection conn;

// Create connection per thread (Main thread)
// Vibe.d is single threaded.
static this()
{
    conn = new Connection(environment["DATABASE_URL"]);
}

class User
{
    ulong id;
    string name;
    string email;
    @pgColumn("email_verified") bool emailVerified;
}

void listUsersHandler(HTTPServerRequest req, HTTPServerResponse res)
{
    string query = "SELECT * FROM users";
    QueryParams qps;
    qps.sqlCommand = query;

    auto rs = conn.execParams(qps);
    User[] users;
    foreach(idx; 0..rs.length)
        users ~= rs[idx].to!User;

    res.writeJsonBody(users);
}

void main()
{
    auto router = new URLRouter;
    router.get("/api/v1/users", &listUsersHandler);

    auto settings = new HTTPServerSettings;
	settings.port = 8080;
	listenHTTP(settings, router);
    runApplication;
}
```

### With Serverino

```d
#!/usr/bin/env dub
/+ dub.sdl:
dependency "serverino" version="~>0.7.9"
dependency "dpq2" version="~>1.1.7"
dependency "dpq2-serialization" path="../dpq2-serialization"
+/
import std.range;
import std.process;

import serverino;
import vibe.data.json;
import dpq2;
import dpq2_serialization;

class User
{
    ulong id;
    string name;
    string email;
    @pgColumn("email_verified") bool emailVerified;
}

Connection conn;

// Create Db connection per worker process
@onWorkerStart void start()
{
    conn = new Connection(environment["DATABASE_URL"]);
}

@endpoint @route!"/api/v1/users"
void listUsersHandler(Request req, Output res)
{
    string query = "SELECT * FROM users";
    QueryParams qps;
    qps.sqlCommand = query;
    auto rs = conn.execParams(qps);
    User[] users;
    foreach(idx; 0..rs.length)
        users ~= rs[idx].to!User;
 
    res.write(serializeToJsonString(users));
}

mixin ServerinoMain;
```
