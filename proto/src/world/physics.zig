const std = @import("std");
const expect = std.testing.expect;
const common = @import("common.zig");


const ObjectOptions = struct {
    position:   common.Vec2Val = common.Vec2Val { .x = 0, .y = 0, },
    angle:      f32 = 0.0,
    velocity:   common.Vec2Val = common.Vec2Val { .x = 0, .y = 0 },
    spin:       f32 = 0,
    drag:       f32 = 0.6
};

const Physics = struct {
    const Self = @This();

    length: u16,
    handleCounter: u16,
    index2handle: std.ArrayList(u16),
    handle2index: std.AutoArrayHashMap(u16, u16),
    _tmp: common.Vec2List,

    positions: common.Vec2List,    // The positions of every game object.
    velocities: common.Vec2List,
    drags: std.ArrayList(f32),
    angles: std.ArrayList(f32),
    spins: std.ArrayList(f32),

    // ==== internal utility ====

    fn indexToHandle(self: *Self, idx: u16) !u16 {
        return try self.index2handle.items[idx];
    }

    fn handleToIndex(self: *Self, handle: u16) !u16 {
        return self.handle2index.get(handle).?;
    }

    // ==== manipulation ====

    pub fn tick(self: *Self, time_delta: f32) !void {
        // velocity -> position
        try self._tmp.copyFrom(&self.velocities);
        try self._tmp.scaleByUnif(time_delta);
        try self.positions.addFrom(&self.velocities);

        // drag -> position
        var idx: u16 = 0;
        while (idx < self.length) {
            defer idx += 1;

            const drag = self.drags.items[idx];
            const vref = try self._tmp.getRef(idx);
            vref.set(vref.get().scaleUnif(drag));
        }

        try self.velocities.subFrom(&self._tmp);

        // angular momenta and their drag
        idx = 0;
        while (idx < self.length) {
            defer idx += 1;

            self.angles.items[idx] += self.spins.items[idx] * time_delta;
            self.spins.items[idx] -= self.spins.items[idx] * self.drags.items[idx] * time_delta;
        }
    }

    fn simulateAhead(self: *Self, seconds: f32, resolution: f32) !void {
        const delta_time = 1.0 / resolution;
        var ticks = seconds * resolution;

        while (ticks >= 1.0) {
            ticks -= 1;
            try self.tick(delta_time);
        }

        try self.tick(delta_time * ticks);
    }

    pub fn make(self: *Self, physOptions: ObjectOptions) !u16 {
        defer self.handleCounter += 1;
        defer self.length += 1;

        const index = self.length;
        const handle = self.handleCounter;

        _ = try self.positions.makeVal(physOptions.position);
        _ = try self.velocities.makeVal(physOptions.velocity);
        _ = try self._tmp.makeArg(0, 0);
        try self.angles.append(physOptions.angle);
        try self.spins.append(physOptions.spin);
        try self.drags.append(physOptions.drag);

        try self.index2handle.append(handle);
        try self.handle2index.put(handle, index);

        return handle;
    }

    pub fn removeHandle(self: *Self, handle: u16) !void {
        try expect(self.handle2index.contains(handle));

        const index = self.handle2index.get(handle).?;
        try self.removeIndex(index, handle);
    }

    pub fn removeIndex(self: *Self, index: u16) !void {
        try expect(index < self.length);

        const handle = self.index2handle.items[index];

        // Pop items
        try self.positions.remove(index);
        try self.velocities.remove(index);
        try self.angles.remove(index);
        try self.spins.remove(index);
        try self.drags.remove(index);
        try self._tmp.remove(index);

        // Update handle index
        self.length -= 1;
        try self.index2handle.remove(index);
        try self.handle2index.remove(handle);

        const newLen = self.length;
        var updIndex = index;

        // redirect the handle from the next index to this one
        while (updIndex < newLen) {
            defer updIndex += 1;

            // since we already removed from index2handle, we shouldn't
            // need to use updIndex + 1 here, or update index2handle at all :D

            // instead, the new handle value should already be in place there,
            // for us to use to update handle2index!
            const updHandle = try self.index2handle[updIndex];

            try expect(self.handle2index.fetchPut(updHandle, updIndex) != null);
        }
    }

    // ==== construction and destruction ====

    pub fn init(allocator: *std.mem.Allocator) Physics {
        return Physics {
            .handleCounter = 0,
            .length = 0,
            .index2handle = std.ArrayList(u16).init(allocator),
            .handle2index = std.AutoArrayHashMap(u16, u16).init(allocator),
            ._tmp = common.Vec2List.init(allocator),
            .positions = common.Vec2List.init(allocator),
            .velocities = common.Vec2List.init(allocator),
            .spins = std.ArrayList(f32).init(allocator),
            .drags = std.ArrayList(f32).init(allocator),
            .angles = std.ArrayList(f32).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.index2handle.deinit();
        self.handle2index.deinit();
        self.positions.deinit();
        self.velocities.deinit();
        self.drags.deinit();
        self.angles.deinit();
        self.spins.deinit();
    }

    // ==== property access ====

    // simple setters and getters
    pub fn getPosition(self: *Self, handle: u16) !common.Vec2Val {
        const index = try self.handleToIndex(handle);
        return try self.positions.get(index);
    }

    pub fn getVelocity(self: *Self, handle: u16) !common.Vec2Val {
        const index = try self.handleToIndex(handle);
        return try self.velocities.get(index);
    }

    pub fn getAngle(self: *Self, handle: u16) f32 {
        const index = try self.handleToIndex(handle);
        return self.angles.items[index] / std.math.tau;
    }

    pub fn getAngleRads(self: *Self, handle: u16) f32 {
        const index = try self.handleToIndex(handle);
        return self.angles.items[index];
    }

    pub fn getAngleDegs(self: *Self, handle: u16) f32 {
        const index = try self.handleToIndex(handle);
        return self.angles.items[index] * (180 / std.math.pi);
    }

    pub fn getSpin(self: *Self, handle: u16) f32 {
        const index = try self.handleToIndex(handle);
        return self.spins.items[index];
    }

    pub fn getDrag(self: *Self, handle: u16) f32 {
        const index = try self.handleToIndex(handle);
        return self.drags.items[index];
    }
    //--
    pub fn setPositionVec(self: *Self, handle: u16, val: common.Vec2Val) !void {
        const index = try self.handleToIndex(handle);
        return try self.positions.setVec(index, val);
    }

    pub fn setVelocityVec(self: *Self, handle: u16, val: common.Vec2Val) !void {
        const index = try self.handleToIndex(handle);
        return try self.velocities.setVec(index, val);
    }

    pub fn setPositionArg(self: *Self, handle: u16, x: f32, y: f32) !void {
        const index = try self.handleToIndex(handle);
        return try self.positions.set(index, x, y);
    }

    pub fn setVelocityArg(self: *Self, handle: u16, x: f32, y: f32) !void {
        const index = try self.handleToIndex(handle);
        return try self.velocities.set(index, x, y);
    }

    pub fn setAngle(self: *Self, handle: u16, angle: f32) !void {
        const index = try self.handleToIndex(handle);
        self.angles.items[index] = angle * std.math.tau;
    }

    pub fn setAngleRads(self: *Self, handle: u16, angle: f32) !void {
        const index = try self.handleToIndex(handle);
        self.angles.items[index] = angle;
    }

    pub fn setAngleDegs(self: *Self, handle: u16, angle: f32) !void {
        const index = try self.handleToIndex(handle);
        self.angles.items[index] = angle * (std.math.pi / 180);
    }

    pub fn setSpin(self: *Self, handle: u16, val: f32) !void {
        const index = try self.handleToIndex(handle);
        self.spins.items[index] = val;
    }

    pub fn setDrag(self: *Self, handle: u16, val: f32) !void {
        const index = try self.handleToIndex(handle);
        self.drags.items[index] = val;
    }

    // position and velocity adjustment
    pub fn offsetPosition(self: *Self, handle: u16, offset: common.Vec2Val) !void {
        const index = try self.handleToIndex(handle);
        const ref = try self.positions.getRef(index);
        ref.set(ref.get().add(offset));
    }

    pub fn offsetPositionScaled(self: *Self, handle: u16, offset: common.Vec2Val, scale: f32) !void {
        const index = try self.handleToIndex(handle);
        const ref = try self.positions.getRef(index);
        ref.set(ref.get().add(offset.scaleUnif(scale)));
    }

    pub fn offsetVelocity(self: *Self, handle: u16, offset: common.Vec2Val) !void {
        const index = try self.handleToIndex(handle);
        const ref = try self.velocities.getRef(index);
        ref.set(ref.get().add(offset));
    }

    pub fn offsetVelocityScaled(self: *Self, handle: u16, offset: common.Vec2Val, scale: f32) !void {
        const index = try self.handleToIndex(handle);
        const ref = try self.velocities.getRef(index);
        ref.set(ref.get().add(offset.scaleUnif(scale)));
    }

    pub fn move(self: *Self, handle: u16, forward: u16, rightward: u16) !void {
        const index = try self.handleToIndex(handle);
        const ref = try self.positions.getRef(index);
        const orig = ref.get();
        const angle = self.angles.items[index];
        const cosv = @cos(angle);
        const sinv = @sin(angle);

        ref.set(orig.offset(
            cosv * forward - sinv * rightward,
            sinv * forward - cosv * rightward
        ));
    }

    pub fn moveVec(self: *Self, handle: u16, frontRight: common.Vec2Val) !void {
        const index = try self.handleToIndex(handle);
        const ref = try self.positions.getRef(index);
        const orig = ref.get();
        const angle = self.angles.items[index];
        const cosv: f32 = @cos(angle);
        const sinv: f32 = @sin(angle);

        ref.set(orig.offset(
            cosv * frontRight.x - sinv * frontRight.y,
            sinv * frontRight.x - cosv * frontRight.y
        ));
    }

    pub fn push(self: *Self, handle: u16, forward: f32, rightward: f32) !void {
        const index = try self.handleToIndex(handle);
        const ref = try self.velocities.getRef(index);
        const orig = ref.get();
        const angle = self.angles.items[index];
        const cosv: f32 = @cos(angle);
        const sinv: f32 = @sin(angle);

        ref.set(orig.offset(
            cosv * forward - sinv * rightward,
            sinv * forward - cosv * rightward
        ));
    }

    pub fn pushVec(self: *Self, handle: u16, frontRight: common.Vec2Val) !void {
        const index = try self.handleToIndex(handle);
        const ref = try self.velocities.getRef(index);
        const orig = ref.get();
        const angle = self.angles.items[index];
        const cosv: f32 = @cos(angle);
        const sinv: f32 = @sin(angle);

        ref.set(orig.offset(
            cosv * frontRight.x - sinv * frontRight.y,
            sinv * frontRight.x - cosv * frontRight.y
        ));
    }

    // angle adjustment
    pub fn offsetAngle(self: *Self, handle: u16, delta_angle: f32) !void {
        const index = try self.handleToIndex(handle);
        self.angles.items[index] += delta_angle * std.math.tau;
    }

    pub fn offsetAngleRads(self: *Self, handle: u16, delta_angle: f32) !void {
        const index = try self.handleToIndex(handle);
        self.angles.items[index] += delta_angle;
    }

    pub fn offsetAngleDegs(self: *Self, handle: u16, delta_angle: f32) !void {
        const index = try self.handleToIndex(handle);
        self.angles.items[index] += (delta_angle * std.math.pi / 180);
    }

    pub fn offsetSpin(self: *Self, handle: u16, delta_spin: f32) !void {
        const index = try self.handleToIndex(handle);
        self.spins.items[index] += delta_spin * std.math.tau;
    }

    pub fn offsetSpinRads(self: *Self, handle: u16, delta_spin: f32) !void {
        const index = try self.handleToIndex(handle);
        self.spins.items[index] += delta_spin;
    }

    pub fn offsetSpinDegs(self: *Self, handle: u16, delta_spin: f32) !void {
        const index = try self.handleToIndex(handle);
        self.spins.items[index] += (delta_spin * std.math.pi / 180);
    }
};

test "movement and consistency" {
    var phys = Physics.init(common.default_ctx.allocator);
    defer phys.deinit();

    const handle = try phys.make(ObjectOptions {
        .position = common.Vec2Val { .x = 0, .y = 0, },
        .velocity = common.Vec2Val { .x = 4, .y = 0, },
        .drag = 0.6,
    });
    try expect(handle == 0);

    if(false){
    try expect((try phys.getPosition(handle)).matches(0, 0));
    try expect((try phys.getVelocity(handle)).matches(4, 0));
    try expect(phys.getDrag(handle) == 0.6);
    try expect(phys.getAngle(handle) == 0);
    try expect(phys.getSpin(handle) == 0);

    const drag_fac = 1.0 - phys.getDrag(handle);
    const drag_fac_half = 1.0 - phys.getDrag(handle) / 2;

    // check with one tick and one second
    try phys.tick(1.0);

    try expect((try phys.getPosition(handle)).matches(4, 0));
    try expect((try phys.getVelocity(handle)).matches(4 * drag_fac, 0));
    try expect(phys.getDrag(handle) == 0.6);
    try expect(phys.getAngle(handle) == 0);
    try expect(phys.getSpin(handle) == 0);

    // revert back
    try phys.setPositionVec(handle, common.Vec2Val { .x = 0, .y = 0 });
    try phys.setVelocityVec(handle, common.Vec2Val { .x = 4, .y = 0 });
    try expect((try phys.getPosition(handle)).matches(0, 0));
    try expect((try phys.getVelocity(handle)).matches(4, 0));

    // check with two ticks and one second
    try phys.tick(0.5);
    try phys.tick(0.5);

    try expect((try phys.getPosition(handle)).matches(2 + 2 * drag_fac, 0));
    try expect((try phys.getVelocity(handle)).matches(4 * drag_fac_half * drag_fac_half, 0));

    // revert back again, this time without velocity
    try phys.setPositionArg(handle, 0, 0);
    try phys.setVelocityArg(handle, 0, 0);
    try expect((try phys.getPosition(handle)).matches(0, 0));
    try expect((try phys.getVelocity(handle)).matches(0, 0));

    // see if it works with angles
    try phys.setAngle(handle, 1.0 / 8.0); // an eighth of a turn is a diagonal to the left (+X, +Y)
    try phys.push(handle, 4, 4);
    try expect(phys.getAngle(handle) == 1.0 / 8.0);
    try expect(phys.getAngleDegs(handle) == 45.0);
    try expect((try phys.getVelocity(handle)).x > 0);
    try expect((try phys.getVelocity(handle)).y < 0);

    try phys.simulateAhead(3, 20); // (20 TPS)

    const pos = try phys.getPosition(handle);
    std.log.info("Two seconds after initial push [forward and rightward], object is now at x={} y={} ang={}deg", .{ pos.x, pos.y, phys.getAngleDegs(handle) });
    try expect(pos.x == pos.y);
    try expect(phys.getAngle(handle) == 1.0 / 8.0);
    try expect(phys.getAngleDegs(handle) == 45.0);
    }
}
