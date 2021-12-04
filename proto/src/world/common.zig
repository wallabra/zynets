const std = @import("std");
const expect = std.testing.expect;


var _gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
const FVec2Oper = fn (orig: f32, other: f32, reflec: f32) f32;
const Vec2SelfOperation = fn (self: *Vec2List, other: *Vec2List) void;

pub const CommonContext = struct {
    allocator: *std.mem.Allocator = &_gpa_state.allocator,
};

pub const default_ctx: CommonContext = CommonContext {
    .allocator = &_gpa_state.allocator,
};

fn add(a: f32, b: f32, _: f32) f32 {
    return a + b;
}

fn sub(a: f32, b: f32, _: f32) f32 {
    return a - b;
}

fn mul(a: f32, b: f32, _: f32) f32 {
    return a * b;
}

fn rotx(x: f32, theta: f32, y: f32) f32 {
    return @cos(theta) * x - @sin(theta) * y;
}

fn roty(y: f32, theta: f32, x: f32) f32 {
    return @sin(theta) * x + @cos(theta) * y;
}

pub const Vec2ValPtr = struct {
    const Self = @This();

    x: *f32,
    y: *f32,

    pub fn get(self: *const Self) Vec2Val {
        return Vec2Val {
            .x = self.x.*,
            .y = self.y.*,
        };
    }

    pub fn set(self: *const Self, other: Vec2Val) void {
        self.x.* = other.x;
        self.y.* = other.y;
    }
};

pub const Vec2Val = struct {
    const Self = @This();

    x: f32,
    y: f32,

    pub fn equal(a: *const Self, b: *const Self) bool {
        return a.x == b.x and a.y == b.y;
    }

    pub fn matches(self: *const Self, x: f32, y: f32) bool {
        return self.x == x and self.y == y;
    }

    pub fn offset(self: *const Self, x: f32, y: f32) Self {
        return Vec2Val {
            .x = self.x + x,
            .y = self.y + y,
        };
    }

    pub fn add(self: *const Self, other: *const Self) Self {
        return Vec2Val {
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn sub(self: *const Self, other: *const Self) Self {
        return Vec2Val {
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }

    pub fn scale(self: *const Self, scalex: f32, scaley: f32) Self {
        return Self {
            .x = self.x * scalex,
            .y = self.y * scaley,
        };
    }

    pub fn scaleUnif(self: *const Self, scalev: f32) Self {
        return Self {
            .x = self.x * scalev,
            .y = self.y * scalev,
        };
    }

    pub fn dot(a: *const Self, b: *const Self) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn rot2(self: *const Self, angle: f32) Self {
        const cosv = @cos(angle);
        const sinv = @sin(angle);

        return Vec2Val {
            .x = cosv * self.x - sinv * self.y,
            .y = sinv * self.x + cosv * self.y,
        };
    }
};

pub const Vec2List = struct {
    const Self = @This();

    length: u16 = 0,
    x: std.ArrayList(f32),
    y: std.ArrayList(f32),

    _tmpx: std.ArrayList(f32),
    _tmpy: std.ArrayList(f32),

    pub fn deinit(self: *Self) void {
        self.x.deinit();
        self.y.deinit();
        self._tmpx.deinit();
        self._tmpy.deinit();
    }

    fn _operFrom(self: *Self, other: *Self, comptime operx: FVec2Oper, comptime opery: FVec2Oper) !void {
        try expect(other.length == self.length);

        var tmpx = &self._tmpx;
        var tmpy = &self._tmpy;

        for (other.x.items) |addx, idx| {
            tmpx.items[idx] = operx(self.x.items[idx], addx, self.y.items[idx]);
        }

        for (other.y.items) |addy, idx| {
            tmpy.items[idx] = opery(self.y.items[idx], addy, self.x.items[idx]);
        }

        for (tmpx.items) |newx, idx| {
            self.x.items[idx] = newx;
        }

        for (tmpy.items) |newy, idx| {
            self.y.items[idx] = newy;
        }
    }

    pub fn copyFrom(self: *Self, other: *Self) !void {
        try expect(other.length == self.length);

        for (other.x.items) |vx, idx| {
            self.x.items[idx] = vx;
        }

        for (other.y.items) |vy, idx| {
            self.y.items[idx] = vy;
        }
    }

    pub fn _operFromVal(self: *Self, val: Vec2Val, comptime operx: FVec2Oper, comptime opery: FVec2Oper) void {
        var tmpx = &self._tmpx;
        var tmpy = &self._tmpy;

        for (self.x.items) |selfx, idx| {
            tmpx.items[idx] = operx(selfx, val.x, self.y.items[idx]);
        }

        for (self.y.items) |selfy, idx| {
            tmpy.items[idx] = opery(selfy, val.y, self.x.items[idx]);
        }

        for (tmpx.items) |newx, idx| {
            self.x.items[idx] = newx;
        }

        for (tmpy.items) |newy, idx| {
            self.y.items[idx] = newy;
        }
    }

    pub fn addFrom(self: *Self, other: *Self) !void {
        try self._operFrom(other, add, add);
    }

    pub fn subFrom(self: *Self, other: *Self) !void {
        try self._operFrom(other, sub, sub);
    }

    pub fn mulFrom(self: *Self, other: *Self) !void {
        try self._operFrom(other, mul, mul);
    }

    pub fn rot2By(self: *Self, other: *Self) !void {
        try self._operFrom(other, rotx, roty);
    }

    pub fn offsetBy(self: *Self, offset: Vec2Val) void {
        self._operFromVal(offset, add, add);
    }

    pub fn scaleBy(self: *Self, scales: Vec2Val) void {
        self._operFromVal(scales, mul, mul);
    }

    pub fn scaleByUnif(self: *Self, scale: f32) !void {
        self.scaleBy(Vec2Val { .x = scale, .y = scale });
    }

    pub fn rotateBy(self: *Self, angle: f32) void {
        self._operFromVal(Vec2Val { .x = angle, .y = angle }, rotx, roty);
    }

    pub fn makeArg(self: *Self, x: f32, y: f32) !u16 {
        try self.x.append(x);
        try self.y.append(y);
        try self._tmpx.append(0);
        try self._tmpy.append(0);

        self.length += 1;
        return self.length - 1;
    }

    pub fn makeVal(self: *Self, vec: Vec2Val) !u16 {
        try self.x.append(vec.x);
        try self.y.append(vec.y);
        try self._tmpx.append(0);
        try self._tmpy.append(0);

        defer self.length += 1;
        return self.length;
    }

    pub fn get(self: *Self, idx: u16) !Vec2Val {
        try expect(idx < self.length);

        return Vec2Val {
            .x = self.x.items[idx],
            .y = self.y.items[idx]
        };
    }

    pub fn getRef(self: *Self, idx: u16) !Vec2ValPtr {
        try expect(idx < self.length);

        return Vec2ValPtr {
            .x = &self.x.items[idx],
            .y = &self.y.items[idx]
        };
    }

    pub fn set(self: *Self, idx: u16, x: f32, y: f32) !void {
        try expect(idx < self.length);

        self.x.items[idx] = x;
        self.y.items[idx] = y;
    }

    pub fn setVec(self: *Self, idx: u16, vec: Vec2Val) !void {
        try expect(idx < self.length);

        self.x.items[idx] = vec.x;
        self.y.items[idx] = vec.y;
    }

    pub fn remove(self: *Self, idx: u16) !Vec2Val {
        try expect(idx < self.length);

        const res = .{ .x = self.x[idx], .y = self.y[idx] };

        self.x.remove(idx);
        self.y.remove(idx);
        self._tmpx.remove(idx);
        self._tmpy.remove(idx);

        return res;
    }

    pub fn init(allocr: *std.mem.Allocator) Self {
        var newself: Self = Vec2List {
            .x = std.ArrayList(f32).init(allocr),
            .y = std.ArrayList(f32).init(allocr),
            ._tmpx = std.ArrayList(f32).init(allocr),
            ._tmpy = std.ArrayList(f32).init(allocr),
        };

        return newself;
    }
};

fn testSetup(list1: *Vec2List, list2: *Vec2List) !void {
    list1.* = Vec2List.init(default_ctx.allocator);
    list2.* = Vec2List.init(default_ctx.allocator);

    _ = try list1.makeArg(2, 2);
    _ = try list1.makeArg(1, 3);
    _ = try list1.makeArg(-2, 0.5);

    _ = try list2.makeArg(2, 1);
    _ = try list2.makeArg(-1, 3);
    _ = try list2.makeArg(-2, 3);
}

test "vector list addition" {
    var list1: Vec2List = undefined;
    var list2: Vec2List = undefined;
    try testSetup(&list1, &list2);
    defer list1.deinit();
    defer list2.deinit();

    try list1.addFrom(&list2);

    try expect((try list1.get(0)).matches(4, 3));
    try expect((try list1.get(1)).matches(0, 6));
    try expect((try list1.get(2)).matches(-4, 3.5));
}
