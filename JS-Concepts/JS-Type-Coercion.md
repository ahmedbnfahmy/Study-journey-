**Type coercion** is JavaScript turning one kind of value into another (usually a **string**, **number**, or **boolean**) so an operation can run. It can be **implicit** (automatic) or **explicit** (you call `Number`, `String`, `Boolean`, etc.).

Source: [Type Coercion — 33 JavaScript Concepts](https://33jsconcepts.com/concepts/type-coercion) · [MDN: Type coercion](https://developer.mozilla.org/en-US/docs/Glossary/Type_coercion)

---
### **1. Implicit vs explicit**

| | **Implicit** | **Explicit** |
| :--- | :--- | :--- |
| **Who decides** | The engine, via operators / context | You, with constructors or parsers |
| **Examples** | `"5" + 3` → `"53"` | `Number("42")` → `42` |

```js
// Implicit
"5" + 3;           // "53"
"5" - 3;           // 2
if ("hello") { }   // string → boolean

// Explicit
Number("42");
String(42);
Boolean(1);
parseInt("42px", 10);
```

---
### **2. Only three “targets”**

Coercion always ends up as one of: **string**, **number**, or **boolean** (per spec’s abstract operations like `ToString`, `ToNumber`, `ToBoolean`).

| Target | Explicit | Common implicit triggers |
| :--- | :--- | :--- |
| **String** | `String(x)`, `.toString()` | `+` with a string, template literals |
| **Number** | `Number(x)`, `+x` | `- * / %`, many comparisons |
| **Boolean** | `Boolean(x)`, `!!x` | `if`, `while`, `!`, `&&`, `\|\|`, ternary |

---
### **3. String conversion**

* Numbers → digit strings; `true`/`false` → `"true"`/`"false"`; `null` → `"null"`; `undefined` → `"undefined"`.
* Arrays → `join(",")` style: `[1,2,3]` → `"1,2,3"`; `[]` → `""`.
* Plain objects → usually `"[object Object]"` via `toString()`.
* **Symbols** cannot be turned into strings implicitly the same way in all contexts — many paths throw **`TypeError`**.

**The `+` operator:** if **any** operand is a string, `+` does **concatenation**, not numeric addition.

```js
5 + 3;           // 8
"5" + 3;         // "53"
1 + 2 + "3";     // "33"   (left-to-right: 3 then "33")
"1" + 2 + 3;     // "123"
```

**Gotcha:** user input from forms is often a string — `input + 10` may concatenate, not add.

---
### **4. Number conversion**

* Numeric strings → number; whitespace trimmed; garbage → **`NaN`**.
* `""` and whitespace-only → **`0`**.
* `true` → `1`, `false` → `0`.
* **`null` → `0`**, **`undefined` → `NaN`** (easy to mix up).
* `[]` → `0` (via empty string); `[5]` → `5`; `[1,2]` → `NaN`; `{}` → `NaN`.

**`-`, `*`, `/`, `%`** only do math → operands tend toward **numbers** (unlike `+`).

```js
"6" - 2;         // 4
Number(null);    // 0
Number(undefined); // NaN
null + 5;        // 5
undefined + 5;   // NaN
```

**Unary `+`:** quick coerce to number: `+"42"` → `42`.

---
### **5. Boolean conversion — the 8 falsy values**

These become **`false`** in boolean context; **everything else is truthy**:

1. `false`
2. `0`
3. `-0`
4. `0n` (BigInt zero)
5. `""`
6. `null`
7. `undefined`
8. `NaN`

**Surprises (truthy):** `"0"`, `"false"` (non-empty strings), `[]`, `{}`.

**`&&` and `||`:** they return an **operand**, not always `true`/`false`:

```js
"hello" || "world";  // "hello"
"" || "world";       // "world"
"hello" && "world";  // "world"
"" && "world";       // ""
```

---
### **6. Objects → primitives (`ToPrimitive`)**

When an object must become a primitive, the engine uses a **hint** (string vs number vs default), then:

1. Optionally **`Symbol.toPrimitive`**
2. Else **`valueOf`** / **`toString`** (order depends on hint)

Arrays: `toString()` joins elements. That is why `[1] == 1` can become true after coercion in `==` (array → `"1"` → number `1`).

---
### **7. Loose equality `==`**

`==` **coerces** types following ECMAScript rules (e.g. `null == undefined` is **`true`**; each is not loosely equal to much else). **`===` does not coerce** — same value and same type (with quirks like `NaN`).

**Practical rule:** prefer **`===`** and **`!==`** unless you deliberately want `==` (e.g. `value == null` to mean null or undefined).

**Famous case:** `[] == ![]` → `true` because `![]` is `false`, then both sides are coerced through the `==` algorithm (boolean → number, object → primitive, etc.). With **`===`**, it is **`false`**.

---
### **8. Quick operator cheat sheet**

| Situation | Tends toward |
| :--- | :--- |
| `+` with any string | String |
| Unary `+` | Number |
| `- * / %`, relational `<` `>` (non-string rules) | Number |
| `==` `!=` | Coercion (complex rules) |
| `===` `!==` | No coercion |
| `if` / `while` / `!` / ternary condition | Boolean context |

---
### **9. Best practices**

1. Default to **`===`** / **`!==`**.
2. Convert explicitly: **`Number()`**, **`String()`**, **`Boolean()`** (or `Number.isFinite`, etc., when validating).
3. Treat user/API input as **untyped** until validated.
4. Use **`Number.isNaN()`** to test for `NaN` (not `=== NaN`; **`NaN !== NaN`**).
5. Watch **`+`** when mixing strings and numbers.

---
### **10. Quick takeaway**

* Coercion = automatic or manual conversion, almost always to **string**, **number**, or **boolean**.
* **`+`** is special: **string anywhere → concatenation**; other math ops favor **numbers**.
* Know the **8 falsy** values; **`[]` and `{}` are truthy**.
* **`==`** is subtle; **`===`** is predictable.
* **Objects** coerce via **`ToPrimitive`** (`Symbol.toPrimitive`, `valueOf`, `toString`).
