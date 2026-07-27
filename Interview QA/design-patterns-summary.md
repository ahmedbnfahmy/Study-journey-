# Design Patterns Summary

Source: https://github.com/leonardomso/33-js-concepts/blob/master/docs/concepts/design-patterns.mdx

## What are Design Patterns?

- Design patterns are reusable solutions to common software design problems.
- They are not exact code snippets, but templates and best-practice approaches.
- The concept was popularized by the Gang of Four (GoF) in their 1994 book.
- JavaScript differs from classical OOP languages, so some patterns become simpler or less necessary.

## Why JavaScript is Different

- First-class functions simplify many patterns.
- Prototypal inheritance avoids complex class hierarchies.
- ES Modules provide built-in modularity and singleton-like behavior.
- Dynamic typing reduces need for interface abstractions.
- Closures make private state easy.

## Pattern Categories

1. Creational Patterns: control how objects are created.
   - Examples: Singleton, Factory Method, Abstract Factory, Builder, Prototype.
2. Structural Patterns: control how objects are composed.
   - Examples: Proxy, Decorator, Adapter, Facade, Bridge, Composite, Flyweight.
3. Behavioral Patterns: control how objects communicate.
   - Examples: Observer, Strategy, Command, Mediator, Iterator, State.

## JavaScript-Specific Pattern

- Module pattern is a JavaScript idiom, not one of the original 23 GoF patterns.
- It is essential for organizing code in JS.

## Patterns Covered

### Module Pattern

- Encapsulates related code with private and public parts.
- Use ES6 modules for modern code.
- Before ES6, IIFE-based modules provided privacy through closures.
- Use when organizing functionality, hiding implementation details, and avoiding global namespace pollution.

### Singleton Pattern

- Ensures only one instance exists and provides a global access point.
- In JavaScript, ES module exports are already singletons because imports are cached.
- Drawbacks: hard to test, hidden dependencies, tight coupling.
- Better alternatives: dependency injection, React Context, exporting objects from modules.
- Useful cases: logging, app configuration, connection pools.

### Factory Pattern

- Creates objects without exposing creation logic.
- Centralizes object construction and supports dynamic object types.
- Good when object setup is complex or the specific type depends on input.
- Prefer plain functions and composition when appropriate.

### Observer Pattern

- Defines a subscription mechanism to notify multiple listeners about events.
- Common in DOM events, React state updates, Redux subscriptions, Node.js EventEmitter.
- Typical implementation has a subscriber list, subscribe/unsubscribe methods, and notify.
- Use for event-driven code and reactive updates.

### Proxy Pattern

- Provides a surrogate object to control access to another object.
- JavaScript's `Proxy` can intercept operations like get, set, and function calls.
- Use cases: validation, logging, lazy initialization, access control, caching.

### Decorator Pattern

**Structural design pattern** — attaches new behaviors to objects by placing them inside special wrapper objects that contain the behaviors.

**Analogy:** Wearing clothes. When you're cold, you wrap yourself in a sweater. Still cold? Add a jacket. Raining? Put on a raincoat. Each garment extends your basic behavior but isn't part of you — and you can take any piece off when you don't need it.

- Works well with objects and functions in JavaScript.
- Supports composition and adding cross-cutting concerns like logging or caching.
- Use when you want to extend behavior without modifying the original object.
- In Angular, `@Component`, `@Injectable`, etc. are **TypeScript decorators** — metadata wrappers applied to classes (related concept, different mechanism).

## Common Mistakes

- Avoid the "Golden Hammer" anti-pattern: don’t use a favored pattern for every problem.
- Ask whether a simpler solution exists.
- Beware of premature abstraction.
- JavaScript idioms often make classical patterns unnecessary.

## Pattern Selection Guide

- Use Module for encapsulation and private state.
- Use Singleton only if you need a single shared instance and alternative patterns do not fit.
- Use Factory for centralized object creation.
- Use Observer for notifying multiple listeners.
- Use Proxy for controlled access to an object.
- Use Decorator for adding behavior without modifying an object.

## Key Takeaways

- Patterns are templates, not rigid rules.
- JavaScript simplifies many patterns through functions, closures, and modules.
- Modern JS favors ES modules over older pattern workarounds.
- Start with the simplest solution and apply patterns only when they solve a real problem.
- Recognize classical patterns in the wild, but adapt them to JavaScript.

## FAQ Highlights

- JavaScript design patterns are reusable solutions adapted to language features.
- Observer is useful when multiple parts need to react to changes.
- Not all GoF patterns are relevant in JavaScript.
- Singleton is often an anti-pattern in JS because module caching already provides similar behavior.
- Proxy differs from Decorator: Proxy controls access, while Decorator adds capabilities.
