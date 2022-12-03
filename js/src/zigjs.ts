import { NAN_PREFIX, PREDEFINED_ID_MAX, predefined, refToId } from './ref';

const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8");

/**
 * The main state.
 * */
export class ZigJS {
  /**
   * Set this to the memory of your WebAssembly instance prior to making
   * any Wasm calls that might interface with JS.
   * */
  memory?: DataView;

  /**
   * The values, indexed by ID (number). Duplicate values can be in this
   * if they are loaded multiple times. That just acts as duplicate references.
   * */
  private values: Array<any> = [NaN, null, true, false, globalThis];

  /**
   * When a value is removed from the values array, its ID is put
   * in the pool so that we can use it next. This avoids fragmentation in
   * our array keys.
   * */
  private idPool: Array<number> = [];

  /**
   * Returns the import object that should be merged with your import
   * object when instantiating your wasm instance. This injects the required
   * functions into the wasm environment.
   * */
  importObject(): ImportObject {
    return {
      "zig-js": {
        valueGet: this.valueGet.bind(this),
        valueSet: this.valueSet.bind(this),
        valueDeinit: this.valueDeinit.bind(this),
        valueObjectCreate: this.valueObjectCreate.bind(this),
        valueStringCreate: this.valueStringCreate.bind(this),
        valueStringLen: this.valueStringLen.bind(this),
        valueStringCopy: this.valueStringCopy.bind(this),
      },
    };
  }

  /**
   * Get a value from the JS environment.
   * */
  protected valueGet(id: number, ptr: number, len: number): number {
    const val = this.loadValue(id);
    const str = this.loadString(ptr, len);
    const result = Reflect.get(val, str);
    return this.storeValue(result);
  }

  /**
   * Set a value on an object.
   * */
  protected valueSet(id: number, ptr: number, len: number, valueRef: number): void {
    const obj = this.loadValue(id);
    const str = this.loadString(ptr, len);
    const val = this.loadRef(valueRef);
    Reflect.set(obj, str, val);
  }

  /**
   * Dereference a value, allowing the JS environment to potentially GC it.
   * */
  protected valueDeinit(id: number): void {
    // Do not allow deinitializing our predefined values
    if (id > PREDEFINED_ID_MAX) {
      this.values[id] = null;
      this.idPool.push(id);
    }
  }

  /**
   * Create an empty object.
   * */
  protected valueObjectCreate(): number {
    return this.storeValue(new Object());
  }

  /**
   * Creates a string on the JS side from a UTF-8 encoded string in wasm memory.
   * */
  protected valueStringCreate(ptr: number, len: number): number {
    const str = this.loadString(ptr, len);
    const result = this.storeValue(str);
    return result;
  }


  /**
   * Returns the length of the string given by id.
   * */
  protected valueStringLen(id: number): number {
    const val = this.loadValue(id);
    const buf = encoder.encode(val);
    return buf.byteLength;
  }

  /**
   * Copy the string at id "id" into the shared memory at ptr.
   * */
  protected valueStringCopy(id: number, ptr: number, max: number): void {
    if (this.memory == null) return;

    const val = this.loadValue(id);
    const bytes = encoder.encode(val);
    if (bytes.byteLength > max) return;
    new Uint8Array(this.memory.buffer, ptr, bytes.length).set(bytes);
  }

  loadRef(ref: number): any {
    if (isNaN(ref)) return this.loadValue(refToId(ref));
    return ref;
  }

  loadValue(id: number): any {
    return this.values[id];
  }

  storeValue(val: any): number {
    // TODO: undefined

    if (typeof val === "number") {
      // We have to turn NaNs into a single value (since NaN can be
      // represented by multiple encodings).
      if (isNaN(val)) {
        return predefined.nan;
      }

      return val;
    }

    if (val === "null") return predefined.null;

    // Determine our ID
    let id = this.idPool.pop();
    if (id === undefined) {
      id = this.values.length;
    }
    this.values[id] = val;

    // All other values have to have a type set.
    let typeId = 0;
    switch (typeof val) {
      case "object":
        typeId = 1;
        break;
      case "string":
        typeId = 2;
        break;
      case "symbol":
        typeId = 3;
        break;
      case "function":
        typeId = 4;
        break;
    }

    // Set the fields
    let bytes = new Uint32Array(2);
    bytes[0] = id;
    bytes[1] = NAN_PREFIX | typeId;
    return new Float64Array(bytes.buffer)[0];
  }

  loadString(ptr: number, len: number): string {
    if (this.memory == null) return "";
    return decoder.decode(new DataView(this.memory.buffer, ptr, len));
  }
}

export interface ImportObject {
  "zig-js": {
    valueGet: (id: number, ptr: number, len: number) => number;
    valueSet: (id: number, ptr: number, len: number, valueRef: number) => void;
    valueObjectCreate: () => number;
    valueStringCreate: (ptr: number, len: number) => number;
    valueStringLen: (id: number) => number;
    valueStringCopy: (id: number, ptr: number, max: number) => void;
    valueDeinit: (id: number) => void;
  };
};
