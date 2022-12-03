const js = @import("zig-js");

export fn set_title() void {
    set_title_() catch unreachable;
}

fn set_title_() !void {
    const doc = try js.global().get("document");
    defer doc.deinit();

    const v = js.Value.init(js.String.init("Hello!"));
    defer v.deinit();

    try doc.set("title", v);
}
