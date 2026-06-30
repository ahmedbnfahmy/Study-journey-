# React

**Status:** To study

---

## What is React?

JavaScript library for building user interfaces with a component-based model. Maintained by Meta. Uses a virtual DOM for efficient updates.

## Core concepts

- **Components** — reusable UI pieces (function or class)
- **JSX** — syntax that looks like HTML inside JavaScript
- **Props** — read-only data passed from parent to child
- **State** — local data that triggers re-renders when it changes
- **Hooks** — `useState`, `useEffect`, `useContext`, custom hooks
- **Virtual DOM** — diff and patch real DOM efficiently

## Key topics to study

- Component lifecycle and `useEffect`
- Lists and keys
- Forms and controlled components
- Context API
- React Router
- Performance (`memo`, `useMemo`, `useCallback`)

---

## Props

Short for **properties** — a way to pass data and functionality from a parent component to a child component. Props are read-only; the child cannot modify them.

---

## Hooks

Feature in React that lets you use state and other React features in **functional components**.

**Built-in hooks:** `useState`, `useEffect`, `useContext`, `useRef`, etc.

**Custom hooks:** Extract reusable logic into your own hook functions and call them from any component.

### `useCallback`

Memoizes a callback function, preventing it from being recreated on each render. Useful when passing callbacks to child components to avoid unnecessary re-renders.

- Takes a function and an array of dependencies.

### `useMemo`

Memoizes the result of a computation, preventing the computation from being repeated on each render. Useful for expensive calculations or avoiding unnecessary re-renders.

- The second argument is an array of dependencies — the value is only recomputed when a dependency changes.

### `useTransition`

Provides a way to asynchronously transition between UI states while keeping React in sync with the transition's progress.

- `startTransition` — initiates the transition
- `isPending` — indicates whether the transition is still in progress

### `useRef`

Creates a reference that persists across renders **without triggering a re-render**.

**DOM reference** — attach to an input (or any element) via the `ref` prop:

```jsx
const inputRef = useRef(null);
// <input ref={inputRef} />
```

**Mutable value** — store and update a value across renders without causing re-renders (unlike `useState`).

### Hooks summary

| Hook | Purpose | Use case | Dependencies? |
| :--- | :--- | :--- | :--- |
| `useCallback` | Memoize functions | Prevent child re-renders | Yes |
| `useMemo` | Memoize values | Optimize expensive calculations | Yes |
| `useTransition` | Defer non-urgent updates | Improve UI responsiveness | No |

---

## Context

Shares data between components without prop drilling — no need to pass props through every level of the tree.

Consists of a **context object** and a **context provider**. Wrap components in `Provider`, read values with `useContext`. Powerful for shared state and configuration.

---

## Virtual DOM

**DOM (Document Object Model)** — the browser's tree representation of the page.

**Virtual DOM** — a programming concept used in React, Vue, and Angular to track changes to the DOM and optimize UI updates. React builds a lightweight copy, diffs it against the previous version, and applies only the minimal changes to the real DOM.

---

## Component Lifecycle

| Phase | Class component | What happens |
| :--- | :--- | :--- |
| **Mounting** | `componentDidMount` | Component is created and inserted into the DOM |
| **Updating** | `componentDidUpdate` | Component re-renders due to props or state change |
| **Unmounting** | `componentWillUnmount` | Component is removed — cleanup runs here |

In functional components, `useEffect` covers these phases via its dependency array and return cleanup function.

---

## The Life Cycle of a State Change

1. **Trigger** — An event happens (e.g. user clicks a button).
2. **Action** — The setter function is called with new data.
3. **Render** — React re-runs the component function.
4. **Reconcile** — React compares the new Virtual DOM with the old one.
5. **Commit** — React updates the browser screen.

---

## Redux

JavaScript library for managing application state, commonly used with React.

- **Store** — single object holding all application state
- **Reducers** — functions that take current state + an action, return new state (immutable — never mutate, always return a new object)
- **Actions** — plain objects describing what changed; dispatched via `dispatch()`
- **Middleware** — intercepts actions before reducers handle them (logging, async work, auth)

Redux provides predictable, centralized state updates — especially useful in large apps.

---

## Axios

HTTP client for making requests from the browser or Node.js. Works with React, Vue, and Angular.

- Simple, consistent API for GET, POST, PUT, DELETE, etc.
- Request/response interceptors
- Automatic JSON serialization/deserialization
- Cancellation and timeout support

---

## Routing

Manages navigation within a React application. **React Router** is the most popular library for defining routes, nested layouts, and URL-driven views.

---

## React JS by Max — Course Notes

### Single Page App (SPA)

One HTML file is delivered to the browser. The imported React app code updates what you see on screen — the page URL may not change on every interaction, but the UI constantly changes.

- **`index.js`** — first file to execute; entry point
- **`App.js`** — root component

```javascript
ReactDOM.render(<App />, document.getElementById('root'));
// React 18+: createRoot(document.getElementById('root')).render(<App />);
```

Renders component `App` into the DOM element with id `root`.

### Create a React project

```bash
npx create-react-app my-first-react-app
npx create-react-app my-first-react-app --template typescript
```

Optional clean setup: delete `src`, recreate it, add `index.js`.

### JSX

JSX is HTML-like syntax inside a JavaScript function — the browser does not understand it directly; it is compiled to `React.createElement` calls.

- Component names: **PascalCase**, one word, describe what the file is about (e.g. `ExpenseForm`)

### Native DOM events

Event listeners like `onClick`:

```jsx
onClick={handleClick}
onClick={functionName}
```

**Why `functionName` without `()`?** Passing the reference runs the function only when clicked. `functionName()` runs immediately when JSX is evaluated during render.

Convention: click handlers often end with `Handler` (e.g. `handleClick`).

### Useful snippets

```javascript
Math.random()                           // random number on each render
Math.random().toString()                // random id
new Date().toISOString()                // date as readable string
```

### State

- Call `useState` only **inside** the functional component — not outside it or inside JSX
- Calling the setter **re-renders** and re-evaluates JSX

**Update based on previous state:**

```javascript
setUserInput((prevState) => {
  return { ...prevState, enteredTitle: event.target.value };
});
```

- Spread `prevState` to keep other fields
- `event.target.value` — current input value from the event listener

### Lifting state up

Move state to a parent component. Child sends data up (via callback props); parent uses it or passes it down to another child.

### Dumb vs smart components

| Type | State | Role |
| :--- | :--- | :--- |
| **Dumb (presentational)** | No state | Display UI from props |
| **Smart (container)** | Has state + logic | Manage data and pass down |

### React DevTools

Chrome extension for inspecting the component tree, props, and state while debugging.

---

## Notes

<!-- Add notes, links, and examples here -->
