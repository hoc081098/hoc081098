# 💠 Union Types in C#

> Estimated reading time: 4 minutes

- Available from **C# 15 / .NET 11 Preview 2**.

- Docs: https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/union#union-implementation
- Proposal: https://github.com/dotnet/csharplang/blob/main/proposals/unions.md

> ⚠️ **Disclaimer — Preview feature**
> - Requires **C# 15 / .NET 11 Preview 2** or later.
> - As of .NET 11 Preview 2, `UnionAttribute` and `IUnion` are **not yet included in the runtime**.
>   You must declare them manually in your project (see [Union implementation](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/union#union-implementation) in the docs).
> - This is a **preview** — APIs and behaviors may change before the final release.

---

## 💠 1. What is a Union Type?

- A union type in C# is a **union of types via a wrapper type**.

- It is a **type union** — **NOT** a *tagged union* or *discriminated union* in the traditional sense.
  Quoted directly from the proposal:
  > *"The proposed unions in C# are unions of **types** and not 'discriminated' or 'tagged'."*

  The distinction:
  - **Discriminated union** (F#, Haskell): uses a dedicated *discriminator/tag* field to tell cases apart.
  - **Type union in C#**: uses the **runtime type** of `Value` itself as the discriminator — no separate tag field.
  - In terms of *behavior*, it resembles a discriminated union in that pattern matching can identify the exact case, but the *storage mechanism* is different.

- It still expresses the **"OR" semantics between types**, but its underlying form is **a box that holds one of the possible types**.

For example, using the **Union declaration syntax**:

```csharp
// Union of existing types
public union Pet(Cat, Dog);
```

Is *lowered* to:

```csharp
[Union] public struct Pet : IUnion
{
    public Pet(Cat value) => Value = value;
    public Pet(Dog value) => Value = value;
    public object? Value { get; }
    ... // original body
}
```

Clearly:

- `Pet` is just **a box** that holds either a `Cat` or a `Dog`
- `Pet` is called the **union type**
- `Cat` and `Dog` are called **case types**

The compiler guarantees **exhaustiveness** when using a union type with pattern matching.

---

## 💠 2. Union Behaviors

### 💠 2.1. Union Conversions

There is an **implicit conversion** from each *case type* to the *union type*:

```csharp
Pet pet = dog;
// becomes
Pet pet = new Pet(dog);
```

### 💠 2.2. Union Matching

#### 💠 2.2.1. Applied to the Inner `Value`

- When the compile-time type of a value is a **union type**,
  pattern matching is implicitly applied to the **`Value` inside the union type**.

  In other words, the union is **implicitly unwrapped** via `.Value`, and the pattern is applied to that `Value`
  *(except when using `var` or `_`)*.

Example:
```csharp
Pet GetPet() => new Dog(...);

var description = GetPet() switch
{
    Dog dog => $"A dog: {dog.name}",
    Cat cat => $"A cat: {cat.name}",
    // No warning about non-exhaustive switch
};
```

Is *lowered* to:

```csharp
GetPet().Value switch {
    ...
}
```

Because the compiler knows `Pet` is a *union type*, it knows the `switch expression` above is already **exhaustive**.

#### 💠 2.2.2. Exception: `var` / `_`

The `var` or `_` patterns are exceptions. In these cases, the pattern is applied to **the `Pet` value itself**, not its `Value`.

```csharp
if (GetPet() is var pet) { ... } // 'pet' is the union value returned from `GetPet`
```

#### 💠 2.2.3. Null Checking

When checking whether a nullable union type variable is `null`,
the `null` check applies not only to the union value itself but also to the `Value` inside it.
(This still follows the Union behavior above — when the compile-time type is a union type.)

```csharp
Pet? pet = ...;
pet is null
```

Is *lowered* to:

```csharp
Pet? pet = ...;

// If Pet is a class union type
pet == null || pet.Value == null

// If Pet is a struct union type
pet.HasValue == false || pet.GetValueOrDefault().Value == null
```

#### 💠 2.2.4. The Trap

```csharp
Pet pet = ...;
pet is Pet
```

This almost always evaluates to `false`, because it is *lowered* to:

```csharp
pet.Value is Pet
```

While `Value` is always `Dog` or `Cat` 😂.

---

## 💠 3. A Common Source of Confusion: Changing the Compile-Time Type Changes the Meaning

If `GetPet()` returns `object`, the story changes entirely.

```csharp
object GetPet() => new Dog(...);

GetPet() is Pet;
```

- Here, `GetPet() is Pet` evaluates to `true` **if `GetPet()` returns an instance of `Pet`**.

  - **Union behavior is not applied**, because the *compile-time type* of the input is `object`, not `Pet`.
  - Therefore, `GetPet() is Pet` is `true` in the sense of a **normal runtime type check**.

- The reason is that the current design only activates **union matching** when the *compile-time type* of the input is already a *union type*.
  Outside of that case, a union is just a regular type / regular value — no implicit `.Value` unwrapping.

- This is explained directly in the proposal discussion: https://github.com/dotnet/csharplang/discussions/10040

---

## 💠 4. Mental Model

```csharp
Pet GetPet()      ->  GetPet() is Pet   // union semantics
object GetPet()   ->  GetPet() is Pet   // normal runtime type check
```

The same syntax `is Pet`, but simply changing the **compile-time type** of the left-hand expression changes the meaning entirely.

This is exactly why many people criticize this proposal as **"not idempotent"** and easy to get confused by.
The discussion at https://github.com/dotnet/csharplang/discussions/10040 also makes it clear that **union pattern matching only activates when the compile-time type is a union type**.

---

## 💠 5. Summary — Quick Reference Snippet

```csharp
// ✅ Union declaration syntax (C# 15 / .NET 11 Preview 2+)
public union Result<T>(T, Exception);

// ✅ Implicit conversion from case type → union type
Result<int> ok    = 42;
Result<int> fail  = new Exception("oops");

// ✅ Pattern matching — exhaustive, no fallback needed
string msg = ok switch
{
    int value    => $"Success: {value}",
    Exception ex => $"Error: {ex.Message}",
    // No warning — compiler knows all cases are covered
};

// ✅ Null check unwraps both layers
// (union declaration → struct → Result<int>? is Nullable<Result<int>>)
Result<int>? maybe = ...;
// lowered: maybe.HasValue == false || maybe.GetValueOrDefault().Value == null
if (maybe is null) { }

// ⚠️ Trap: always false due to implicit unwrapping
Result<int> r = ...;
r is Result<int>                            // → r.Value is Result<int> → false!

// ⚠️ Compile-time type determines behavior
Result<int>  r2 = ...;  r2 is int           // union semantics ✅
object       r3 = ...;  r3 is Result<int>   // normal runtime type check ⚠️
```

