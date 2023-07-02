const js = @import("zig-js");

export fn set_title() void {
    set_title_() catch unreachable;
}

export fn alert() void {
    alert_() catch unreachable;
}

fn set_title_() !void {
    const doc = try js.global.get(js.Object, "document");
    defer doc.deinit();

    try doc.set("title", js.string("Hello!"));
}

export fn zig_eval() void {
    __zig_eval() catch unreachable;
}

fn __zig_eval() !void {
    const script = js.string(@embedFile("example.payload.js"));

    const doc = try js.global.get(js.Object, "document");

    _ = try doc.eval(void, script);
}

fn alert_() !void {
    try js.global.call(void, "alert", .{js.string("Hello, world!")});
}
