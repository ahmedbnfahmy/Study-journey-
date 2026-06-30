# Angular

**Status:** To study

---

## What is Angular?

Full-featured TypeScript framework for building web applications. Maintained by Google. Opinionated structure with modules, services, and dependency injection.

## Core concepts

- **Components** — template + class + metadata (`@Component`)
- **Modules** — `NgModule` bundles related features (`AppModule`)
- **Templates** — HTML with directives and data binding
- **Services** — shared logic and data (`@Injectable`)
- **Dependency Injection** — framework provides dependencies to constructors
- **RxJS** — observables for async data streams

## Key topics to study

- Data binding (interpolation, property, event, two-way)
- Directives (`*ngIf`, `*ngFor`, custom directives)
- Routing (`RouterModule`, guards, lazy loading)
- Forms (template-driven vs reactive)
- HttpClient and interceptors
- Change detection

---

## Components

App building blocks — reusable, self-contained units that break the app into smaller, manageable pieces.

Each component consists of:

- A **TypeScript class** (logic and data)
- An **HTML template** (view)
- Optional **styles** (scoped CSS)

---

## Templates

HTML syntax with **directives** and **binding expressions**. Responsible for rendering data and defining how the UI looks.

---

## Directives

Tell Angular to do something to a DOM element.

**Built-in examples:** `*ngIf`, `*ngFor`, `ngSwitch`

| Type | Role |
| :--- | :--- |
| Structural | Change DOM layout (`*ngIf`, `*ngFor`) |
| Attribute | Change appearance or behavior of an element |

---

## Data Binding

Synchronization of data between the model and the view. Angular supports **one-way** and **two-way** binding.

| Type | Syntax | Direction |
| :--- | :--- | :--- |
| Interpolation | `{{ value }}` | Component → view |
| Property | `[property]="value"` | Component → view |
| Event | `(event)="handler()"` | View → component |
| Two-way | `[(ngModel)]="value"` | Both directions |

---

## Modules

Organize and structure an application by grouping related functionality together (`NgModule`). Declares components, imports other modules, provides services.

---

## Router

Navigate between components based on the current URL.

- **Lazy loading** — load feature modules on demand
- **Guards** — control access to routes (`CanActivate`, `CanDeactivate`)

---

## Lifecycle Hooks

Perform actions at specific points in a component's lifecycle — initialization, data updates, and cleanup.

| Hook | When |
| :--- | :--- |
| `ngOnInit` | After first `ngOnChanges`; initialization logic |
| `ngOnChanges` | When input properties change |
| `ngOnDestroy` | Before component is destroyed; cleanup |

---

## Dependency Injection (DI)

Angular's injector provides dependencies to components and services. Makes it easier to create and test components in isolation — swap real services for mocks in tests.

---

## Design Patterns

Patterns to know when working with Angular.

### MVC — Structure Pattern

**Model-View-Controller** — architecture split into three distinct parts:

| Layer | Role |
| :--- | :--- |
| **Model** | Pure application data — interfaces or classes without logic; represents transient data used in the app |
| **View** | Presents the model's data in the UI (HTML template). Knows how to access the data, but not what it means |
| **Controller** | Sits between view and model; links the two layers (in Angular, the component class often plays this role) |

---

### Singleton — Creational Pattern

Ensures a class has only **one instance** and provides a global access point to it.

**Problem:** Ensure a class has just a single instance.

**How (classic implementation):**

1. Make the default constructor **private**
2. Create a **static creation method** that acts as a constructor
3. The method calls the private constructor, saves the object in a static field, and returns the cached object on every subsequent call

**In Angular:** Dependency injection manages this for you.

- Services provided at the **root** (`providedIn: 'root'`) are **singleton** instances
- Services provided at the **component** level are **not** singleton — a new instance per component

---

### Observer — Behavioral Pattern

Defines a **subscription mechanism** to notify multiple objects when events happen to the object they're observing.

**Problem (store example):**

- A customer wants a new iPhone — visiting the store daily is wasteful while the product is still in transit
- The store emailing every customer on every new product spams uninterested people

**Solution:**

- The object with interesting state is the **publisher** (subject)
- Objects that want updates are **subscribers**
- Add subscribe/unsubscribe to the publisher so subscribers receive a stream of events

**In Angular:** **Observables (RxJS)** implement this pattern — better than promises for multiple values over time, cancellation, and operators. Used throughout Angular for HTTP, forms, and event streams.

---

## Notes

<!-- Add notes, links, and examples here -->
