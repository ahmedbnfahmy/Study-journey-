To understand **Primitives vs Objects** in JavaScript, focus on **behavior (mutability + identity)**, not “stack vs heap”.

Source: `https://33jsconcepts.com/concepts/primitives-objects`
---
### **1. What JavaScript actually has**
ECMAScript defines two categories of values:
* **Primitive values:** `string`, `number`, `bigint`, `boolean`, `undefined`, `null`, `symbol`
* **Objects:** everything else (plain objects, arrays, functions, dates, maps, sets, ...)

---
### **2. The real difference: mutability**
* **Primitives are immutable** → you can’t change the value, only replace it.
* **Objects are mutable** → you can change their contents (properties/elements) in place.

Example (primitives):
```js
let greeting = "hello";
let shout = greeting.toUpperCase();

console.log(greeting); // "hello" (unchanged)
console.log(shout);    // "HELLO" (new value)
```

Example (objects):
```js
const user = { name: "Alice" };
user.name = "Bob";     // mutation (in-place)
console.log(user.name); // "Bob"
```

---
### **3. Assignment / copying behavior**
* **Copying primitives** behaves like independent values.
* **Copying objects** copies the **reference** (so both variables can point to the same object).

```js
let a = 10;
let b = a;
b = 20;
console.log(a, b); // 10 20

let obj1 = { count: 1 };
let obj2 = obj1;       // shared reference
obj2.count = 5;        // mutation affects same object
console.log(obj1.count); // 5
```

Arrays are objects too:
```js
const arr1 = [1, 2, 3];
const arr2 = arr1;
arr2.push(4);
console.log(arr1); // [1,2,3,4]
```

---
### **4. Equality rules**
* **Primitives**: compared by **value** (except `symbol` which is unique by identity).
* **Objects**: compared by **identity** (same reference), not by structure.

```js
console.log("a" === "a"); // true
console.log({} === {});   // false (different objects)

const x = {};
const y = x;
console.log(x === y);     // true (same object)
```

---
### **5. “Pass by value vs reference” → call by sharing**
JavaScript uses **call by sharing** for *all* values:
* The function receives a **copy of the reference**.
* **Mutating** the object through that reference affects the original.
* **Reassigning** the parameter does not affect the caller variable.

Mutation works:
```js
function rename(person) {
  person.name = "Bob";  // mutates shared object
}

const user = { name: "Alice" };
rename(user);
console.log(user.name); // "Bob"
```

Reassignment doesn’t:
```js
function replace(person) {
  person = { name: "Charlie" }; // only rebinds local parameter
}

const user = { name: "Alice" };
replace(user);
console.log(user.name); // "Alice"
```

---
### **6. Mutation vs reassignment + the `const` “trap”**
* **Mutation**: change the contents of an object/array.
* **Reassignment**: point the variable to a new value.
* `const` prevents **reassignment**, not **mutation**.

```js
const nums = [1, 2, 3];
nums.push(4);     // ✅ allowed (mutation)
// nums = [9];    // ❌ error (reassignment)
```

---
### **7. `var` vs `let` vs `const`**

| | **`var`** | **`let`** | **`const`** |
| :--- | :--- | :--- | :--- |
| **Scope** | Function-scoped (or global if top-level) | Block-scoped (`{}`) | Block-scoped (`{}`) |
| **Reassignment** | Allowed | Allowed | **Not** allowed (binding is fixed) |
| **Redeclaration** (same scope) | Allowed | Error | Error |
| **Hoisting / TDZ** | Hoisted; initialized as `undefined` before use | **Temporal dead zone** until declaration line | **TDZ** until declaration line |
| **Initial value** | Optional (`var x;` is ok) | Optional (`let x;` then assign later) | **Required** at declaration (`const x = ...`) |
| **Use today** | Legacy; avoid in new code | Mutable bindings | Default for values that should not be rebound |

**Note:** `const` only fixes the **binding** (the variable name). Object/array **contents** can still be mutated unless you freeze or use immutable patterns.

---
### **8. Binding, hoisting, and TDZ (summary)**

#### **What “binding” means**
A **binding** is the link between a **name** (identifier) and a **value** (or storage for that value) in a given **scope**.

* **`let x = 1`** → creates a binding: `x` refers to that value until reassigned.
* **`const o = {}`** → the **name** `o` is permanently tied to **that object**; you cannot point `o` at a different value, but you can still **mutate** the object’s contents.

```js
let x = 1;
x = 2;        // same binding, new value

const o = {};
o.a = 1;      // mutation ok; binding o → same object
```

**Hoisting / TDZ** are about **when the name exists** and **when you may read it**, not about whether a value is mutable.

#### **Hoisting**
**Hoisting** describes how JavaScript **creates variable bindings** before running the rest of the code in that scope.

* **`var`:** the binding exists for the whole function/script scope and is initialized as **`undefined`** immediately, so reading it before the assignment line does not throw:

```js
console.log(x); // undefined (not ReferenceError)
var x = 1;
```

* **`function` declarations** (not `const fn = function () {}`): the function is available for the whole scope, so calls above the declaration work.

* **`let` / `const`:** bindings are also created when the scope runs, but they are **not** initialized like `var` → that leads to the TDZ.

#### **TDZ (Temporal Dead Zone)**
The **temporal dead zone** is the period from the **start of the block** until the **`let`/`const` declaration line**. In that window you **must not read** the variable; doing so throws **`ReferenceError`** (not `undefined`):

```js
{
  console.log(a); // ReferenceError (TDZ)
  let a = 1;
  console.log(a); // 1
}
```

**Why TDZ exists:** it prevents the confusing `var` behavior where you read `undefined` instead of getting a clear error for “use before real initialization.”

#### **Quick contrast: `var` vs `let` / `const`**

| | **`var`** | **`let` / `const`** |
| :--- | :--- | :--- |
| Read before declaration in same scope | Allowed → **`undefined`** | **`ReferenceError`** (TDZ) |
| Scope | Function (or global) | Block |

**Mental model:** **hoisting** = bindings are set up when the scope runs; **TDZ** = for `let`/`const`, the name must not be read until the declaration runs; **`var`** skips TDZ by starting as **`undefined`**.

---
### **9. Shallow vs deep copy**
**Shallow copy** (copies top-level only; nested objects are still shared):
```js
const original = { name: "Alice", address: { city: "NYC" } };
const shallow = { ...original };
shallow.address.city = "LA";
console.log(original.address.city); // "LA" (nested shared)
```

**Deep copy** (fully independent):
```js
const deep = structuredClone(original);
deep.address.city = "Paris";
console.log(original.address.city); // "LA" (unchanged by deep)
```

---
### **10. Quick takeaway**
* **Primitives:** immutable, compared by value, behave independently.
* **Objects:** mutable, compared by identity, can be shared across variables/functions.
* **Key rule:** *mutation passes through shared references; reassignment does not.*
* **`const` / binding:** `const` locks the **name → value** link; objects can still be mutated.
* **Hoisting / TDZ:** `var` is usable early as `undefined`; `let`/`const` throw if read before their line (TDZ).

