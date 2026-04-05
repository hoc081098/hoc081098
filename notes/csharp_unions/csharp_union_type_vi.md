# 💠 Union types trong C# (bản Tiếng Việt)

> Estimated reading time: 4 minutes

- Có sẵn từ **C# 15 / .NET 11 Preview 2**.

- Docs: https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/union#union-implementation
- Proposal: https://github.com/dotnet/csharplang/blob/main/proposals/unions.md

> ⚠️ **Disclaimer — Preview feature**
> - Yêu cầu **C# 15 / .NET 11 Preview 2** trở lên.
> - Tính đến .NET 11 Preview 2, `UnionAttribute` và `IUnion` **chưa được include trong runtime**.
>   Muốn dùng phải tự khai báo trong project (xem mục [Union implementation](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/union#union-implementation) trong docs).
> - Đây là **preview** — API và behavior có thể thay đổi trước khi ship chính thức.

---

## 💠 1. Bản chất

- Union types trong C# là **union of types thông qua một wrapper type**.

- Nó là **type union** — **KHÔNG phải** *tagged union* hay *discriminated union* theo nghĩa truyền thống.
  Trích trực tiếp từ proposal:
  > *"The proposed unions in C# are unions of **types** and not 'discriminated' or 'tagged'."*

  Sự khác biệt:
  - **Discriminated union** (F#, Haskell): dùng một trường *discriminator/tag* riêng biệt để phân biệt case.
  - **Type union trong C#**: dùng chính **runtime type** của `Value` làm discriminator — không có trường tag riêng.
  - Về *hành vi*, nó tương tự discriminated union ở chỗ pattern matching có thể biết chính xác đang ở case nào, nhưng về *cơ chế lưu trữ* thì khác.

- Nó vẫn đại diện cho ngữ nghĩa **"HOẶC" giữa các type**, nhưng bản chất của nó là **một cái hộp chứa type cần "hoặc" ở bên trong**.

Ví dụ, ta dùng **Union declaration syntax**:

```csharp
// Union of existing types
public union Pet(Cat, Dog);
```

Được *lowered* thành:

```csharp
[Union] public struct Pet : IUnion
{
    public Pet(Cat value) => Value = value;
    public Pet(Dog value) => Value = value;
    public object? Value { get; }
    ... // original body
}
```

Ta thấy rõ:

- `Pet` chỉ là **một cái hộp**, hoặc chứa `Cat`, hoặc chứa `Dog`
- `Pet` được gọi là **union type**
- `Cat` và `Dog` được gọi là **case types**

Compiler sẽ đảm bảo **exhaustiveness** khi dùng Union type với pattern matching.

---

## 💠 2. Hành vi (union behaviors)

### 💠 2.1. Union conversions

Có **implicit conversion** từ mỗi _case type_ sang _union type_:

```csharp
Pet pet = dog;
// becomes
Pet pet = new Pet(dog);
```

### 💠 2.2. Union matching

#### 💠 2.2.1. Apply vào `Value` bên trong

- Khi kiểu dữ liệu của một value là **union type tại compile time**, 
  thì pattern matching sẽ được áp dụng lên **`Value` bên trong union type một cách ngầm định**.

  Nghĩa là nó sẽ bị **unwrap ngầm định** thông qua `.Value`, rồi apply pattern lên `Value` đó  
  *(ngoại trừ trường hợp dùng `var` hoặc `_`)*.

Ví dụ:
```csharp
Pet GetPet() => new Dog(...);

var description = GetPet() switch
{
    Dog dog => $"A dog: {dog.name}",
    Cat cat => $"A cat: {cat.name}",
    // No warning about non-exhaustive switch
};
```

Được *lowered* thành:

```csharp
GetPet().Value switch {
    ...
}
```

Vì compiler biết `Pet` là một _union type_, nên nó sẽ biết `switch expression` ở trên đã được **exhaustive** rồi.

#### 💠 2.2.2. Ngoại lệ `var` / `_`

Ngoại lệ là `var` hoặc `_` pattern. Khi đó, pattern sẽ được apply vào **chính `Pet` value**, chứ không phải `Value` của `Pet`.

```csharp
if (GetPet() is var pet) { ... } // 'pet' is the union value returned from `GetPet`
```

#### 💠 2.2.3. Check `null`

Khi check 1 biến kiểu nullable union type là `null` hay không,
thì việc check `null` không chỉ apply cho union type value, mà cả `Value` bên trong union type.
(Điều này vẫn tuân thủ Union behavior ở trên - khi compile-time type là union type)

```csharp
Pet? pet = ...;
pet is null
```

Được *lowered* thành:

```csharp
Pet? pet = ...;

// Nếu Pet là class union type
pet == null || pet.Value == null

// Nếu Pet là struct union type
pet.HasValue == false || pet.GetValueOrDefault().Value == null
```

#### 💠 2.2.4. Cạm bẫy

```csharp
Pet pet = ...;
pet is Pet
```

Nó gần như luôn eval thành `false`, vì nó bị *lowered* thành:

```csharp
pet.Value is Pet
```

Trong khi `Value` luôn là `Dog` hoặc `Cat` 😂.

## 💠 3. Một chỗ rất dễ gây nhầm lẫn: compile-time type đổi thì meaning cũng đổi

Nếu `GetPet()` trả về kiểu `object`, thì câu chuyện đổi hẳn.

```csharp
object GetPet() => new Dog(...);

GetPet() is Pet;
```

- Khi đó, `GetPet() is Pet` sẽ eval thành `true` **nếu `GetPet()` trả về một instance của `Pet`**.

  - Lúc này, **union behavior sẽ không được áp dụng**, vì _compile-time type_ của giá trị đầu vào là `object`, không phải `Pet`.
  - Do đó, `GetPet() is Pet` sẽ là `true` theo nghĩa **check type bình thường ở runtime**.

- Lý do là thiết kế hiện tại chỉ bật **union matching** khi _compile-time type_ của giá trị đầu vào đã là _union type_.
  Ngoài trường hợp đó, union chỉ là một type bình thường / value bình thường, không có unwrap `.Value` ngầm.

- Đây là giải thích trực tiếp từ thảo luận của proposal: https://github.com/dotnet/csharplang/discussions/10040

## 💠 4. Mental model

```csharp
Pet GetPet()      ->  GetPet() is Pet   // union semantics
object GetPet()   ->  GetPet() is Pet   // normal runtime type check
```

Tức là cùng một cú pháp `is Pet`, nhưng chỉ cần đổi **compile-time type** của biểu thức bên trái là meaning sẽ đổi theo.

Đây chính là lý do nhiều người chê proposal này **"không idempotent"** và dễ gây lú.
Trong discussion https://github.com/dotnet/csharplang/discussions/10040 cũng nêu khá rõ rằng **union pattern matching chỉ hoạt động khi compile-time type là union type**.

---

## 💠 5. Tổng hợp — snippet dễ nhớ

```csharp
// ✅ Union declaration syntax (C# 15 / .NET 11 Preview 2+)
public union Result<T>(T, Exception);

// ✅ Implicit conversion từ case type → union type
Result<int> ok    = 42;
Result<int> fail  = new Exception("oops");

// ✅ Pattern matching — exhaustive, không cần fallback
string msg = ok switch
{
    int value    => $"Success: {value}",
    Exception ex => $"Error: {ex.Message}",
    // No warning — compiler biết đã exhaustive
};

// ✅ null check unwrap cả hai tầng

// (union declaration → struct → Result<int>? is Nullable<Result<int>>)
Result<int>? maybe = ...;

// lowered: maybe.HasValue == false || maybe.GetValueOrDefault().Value == null
if (maybe is null) { }

// ⚠️ Cạm bẫy: luôn false vì bị unwrap ngầm
Result<int> r = ...;
r is Result<int>                                // → r.Value is Result<int> → false!

// ⚠️ Compile-time type quyết định behavior
Result<int>  r2 = ...;  r2 is int               // union semantics ✅
object       r3 = ...;  r3 is Result<int>       // runtime type check thường ⚠️
```
