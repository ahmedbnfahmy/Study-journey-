# SOLID Principles

Design principles for maintainable, scalable object-oriented software.

---

## Overview

| Design Principle | Description |
| :--- | :--- |
| **Single Responsibility Principle (SRP)** | Every class should have only one responsibility or job. Encourages the design of small, focused classes that do one thing well, improving code readability, maintainability, and testability. **Use SRP** to create smaller, focused components/functions. |
| **Open/Closed Principle (OCP)** | Classes, modules, and functions should be **open for extension** but **closed for modification**. Allows adding new functionality without changing existing code. Achieved through interfaces, abstract classes, and polymorphism. **Follow OCP** by using composition and dependency injection. |
| **Liskov Substitution Principle (LSP)** | Subtypes must be substitutable for their base types without altering the correctness of the program. Objects of a subtype can replace objects of the supertype. Related to polymorphism and inheritance. **Maintain LSP** when extending classes or implementing interfaces. |
| **Interface Segregation Principle (ISP)** | A class should not be forced to depend on interfaces it does not use. Encourages the creation of small, client-specific interfaces to avoid forcing classes to implement unnecessary methods. **Apply ISP** by keeping interfaces/contracts small and specific. |
| **Dependency Inversion Principle (DIP)** | High-level modules should not depend on low-level modules; both should depend on **abstractions**. Abstractions should not depend on details; details should depend on abstractions. Encourages flexibility and maintainability through dependency injection and inversion of control. **Implement DIP** by depending on abstractions rather than concretions. |

---

## Takeaway

The SOLID principles collectively contribute to code that is easy to extend, modify, and maintain, fostering a scalable and robust software design.

---

## Notes

<!-- Add examples, links, and language-specific notes here -->
