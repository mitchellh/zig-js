# zig-js

zig-js is a Zig library (and accompanying JS glue) that enables Zig
running in a WebAssembly environment to interact with a JavaScript-based
host.

## Example

```zig
const document = try js.global().get("document");
defer document.deinit();

const title = try document.get("title");
defer title.deinit();

const str = try title.string(alloc)
std.log.info("the title is: {s}", .{str});
```

The code is a bit verbose with the error handling but since JS is a
dynamic language there are potential invalid types at every step of the
way. Additionally, `deinit` calls are necessary to dereference garbage-collected
values on the host side.

Under the covers, this is hiding a lot of complexity since the JS/WASM
ABI only allows passing numeric types and sharing memory.

## Usage

To use this library, you must integrate a component in both the Zig
and JS environment. For Zig, vendor this repository and add the package.
For example in your build.zig:

```
TODO
```

From JS, install and import the package in the `js/` directory (in the future
this will be published to npm). A TypeScript example is shown below but
JS could just as easily be used:

```typescript
import { ZigJS } from 'zig-js';

// Initialize the stateful zigjs class. You should use one per wasm instance.
const zigjs = new ZigJS();

fetch('my-wasm-file.wasm').then(response =>
  response.arrayBuffer()
).then(bytes =>
  // When creating your Wasm instance, pass along the zigjs import
  // object. You can merge this import object with your own since zigjs
  // uses its own namespace.
  WebAssembly.instantiate(bytes, zigjs.importObject())
).then(results => {
  const { memory, my_func } = results.instance.exports;

  // Set the memory since zigjs interfaces with memory.
  zigjs.memory = new DataView(memory.buffer);

  // Run any of your exported functions!
  my_func();
});
```

## Internals

The fundamental idea in this is based on the Go
[syscall/js](https://pkg.go.dev/syscall/js) package. The implementation
is relatively diverged since Zig doesn't have a runtime or garbage collection,
but the fundamental idea of sharing "refs" and the format of those refs is
based on Go's implementation.

The main idea is that Zig communicates to JS what values it would like
to request, such as the "global" object. JS generates a "ref" for this
object (a unique 64-bit numeric value) and sends that to Zig. This ref now
uniquely identifies the value for future calls such as "give me the
'document' property on this ref."

The ref itself is a 64-bit value. For numeric types, the ref _is_ the
value. We take advantage of the fact that all numbers in JavaScript are
IEEE 754 encoded 64-bit floats and use NaN as a way to send non-numeric values
to Zig.

NaN in IEEE 754 encoding is `0111_1111_1111_<anything but all 0s>` in binary.
We use a common NaN value of `0111_1111_1111_1000_0000...` so that we can use
the bottom (least-significant) 49 bits to store type information and
a 32-bit ID.

The 32-bit ID is just an index into an array on the JS side. A simple scheme
is used to reuse IDs after they're dereferenced.
