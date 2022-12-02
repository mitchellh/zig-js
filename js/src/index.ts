const nan_prefix = 0x7FF8_0000;
const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8");

const PREDEFINED_ID_MAX = 4;

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
        valueDeinit: this.valueDeinit.bind(this),
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
   * Dereference a value, allowing the JS environment to potentially GC it.
   * */
  protected valueDeinit(id: number): void {
    // Do not allow deinitializing our predefined values
    if (id > PREDEFINED_ID_MAX) {
      this.values[id] = null;
      this.idPool.push(id);
    }
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
    bytes[1] = nan_prefix | typeId;
    return new Float64Array(bytes.buffer)[0];
  }

  loadString(ptr: number, len: number): string {
    if (this.memory == null) return "";
    return decoder.decode(new DataView(this.memory.buffer, ptr, len));
  }
}

export const predefined = {
  "nan": idToRef(0),
  "null": idToRef(1),
  "true": idToRef(2),
  "false": idToRef(3),
  "globalThis": idToRef(4),
};

export interface ImportObject {
  "zig-js": {
    valueGet: (ref: number, ptr: number, len: number) => number;
    valueDeinit: (id: number) => void;
  };
};

/**
 * Convert an id to a ref. These are only exported so they can be tested.
 *
 * @private
 * */
export function idToRef(id: number): number {
  let bytes = new Uint32Array(2);
  bytes[0] = id;
  bytes[1] = nan_prefix;
  return new Float64Array(bytes.buffer)[0];
}

/**
 * Convert an ref to an ID. This is only exported so it can be tested.
 *
 * @private
 * */
export function refToId(ref: number): number {
  let floats = new Float64Array([ref]);
  let bytes = new Uint32Array(floats.buffer);
  return bytes[0];
}
