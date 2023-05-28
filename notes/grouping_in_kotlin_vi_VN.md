# Grouping trong Kotlin (Grouping in Kotlin).
## Author: [Petrus Nguyễn Thái Học](https://github.com/hoc081098)

- _Tags_: #kotlin, #grouping, #groupingBy, #groupBy, #reduce, #lazy-evaluation, #functional-programming, #hoc081098, #rx_mobile_team,
#kotlindev #androiddev
- _Source code_: https://github.com/hoc081098/hoc081098/blob/master/notes/grouping_in_kotlin_vi_VN.kt

## Đặt vấn đề

Giả sử chúng ta có một bài toán nhỏ như sau:

- Input: cho danh sách các sinh viên, mỗi sinh viên có các thuộc tính như sau
  - `id`: mã sinh viên.
  - `name`: tên sinh viên.
  - `classId`: mã lớp.
  - `avgScore`: điểm trung bình.

- Output: cho biết sinh viên có điểm trung bình cao nhất của mỗi lớp, kết quả được sắp xếp theo thứ tự tăng dần của mã lớp.

```kotlin
// Input: A list of Students, each Student has id, name, class_id, avg_score.
// Output: Map of class_id to the student with the highest avg_score in that class.
//         Keys should be sorted in ascending order.
// Example:
// Input: [
//   Student("1", "A", 1, 8.0),
//   Student("2", "B", 1, 9.0),
//   Student("3", "A", 2, 7.0),
// ]
// Output: {
//   1: Student("2", "B", 1, 9.0),
//   2: Student("3", "A", 2, 7.0),
// }

data class Student(
  val id: String,
  val name: String,
  val classId: Int,
  val avgScore: Double
)

@JvmField
val compareByAvgScore = compareBy<Student> { it.avgScore }

// (TreeMap take O(log n) time in the worst case to get/put).
typealias Output = SortedMap<Int, Student>

fun solution(students: List<Student>): Output = TODO()

fun main() {
  val students = listOf(
    Student("1", "A", 1, 8.0),
    Student("2", "B", 1, 9.0),
    Student("3", "A", 2, 7.0),
  )
  val output = mapOf(
    1 to Student("2", "B", 1, 9.0),
    2 to Student("3", "A", 2, 7.0),
  )
  check(solution(students) == output)
}
```

## Solution 1: Sử dụng vòng lặp

Cách này ổn về mặt thời gian và không gian, nhưng cách viết khá dài dòng và khó đọc, và theo imperactive style
  (for loop + if statement).

```kotlin
// Time complexity (worst case) = n * (O(log n) + O(log n)) = O(2 * n * log n).
// Space: 1 TreeMap.
// ----
// Pros: good in terms of time complexity and space complexity.
// Cons: imperative style.
fun solution1(students: List<Student>): Output {
  val result = sortedMapOf<Int, Student>()
  for (student in students) {
    val current = result[student.classId]
    if (current == null || student.avgScore > current.avgScore) {
      result[student.classId] = student
    }
  }
  return result
}
```

## Solution 2: Sử dụng `groupBy` và `mapValues`

Cách này sử dụng functional style, nhưng không tốt về mặt thời gian và không gian.
Nó phải tạo ra 1 HashMap trung gian, và một TreeMap (SortedMap) để lưu kết quả.
Ngoài ra, nó cũng phải duyệt 3 lần, 1 lần để groupBy, 1 lần để mapValues, trong mỗi lần mapValues lại phải duyệt để tìm max.

```kotlin
// Time complexity (worst case)
//     - groupByTo: O(n * ( O(1) + O(n) )) = O(n^2)
//     - mapValuesTo: O(n * ( O(log n) + O(n) )) = O(n^2 * log n)
//     - total: O(n^2 * log n)
// Space: 1 HashMap + 1 TreeMap
// ----
// Pros: functional style.
// Cons: bad in terms of time complexity and space complexity.
fun solution2(students: List<Student>): SortedMap<Int, Student> = students
  .groupByTo(hashMapOf()) { it.classId }
  .mapValuesTo(sortedMapOf()) { (_, v) -> v.maxBy { it.avgScore } }
```

## Solution 3: Sử dụng `groupingBy` và `reduce`

```kotlin
// Time complexity (worst case)
//     - groupingBy: O(1) (just returns a Grouping object)
//     - reduceTo: O(n * ( O(log n) + O(log n) )) = O(n * log n)
//     - total: O(2 * n * log n)
// Space: 1 TreeMap (Grouping object is small).
// ----
// Pros: BEST. Functional style, good in terms of time complexity and space complexity.
// Cons: NO.
fun solution3(students: List<Student>): SortedMap<Int, Student> = students
  .groupingBy { it.classId }
  .reduceTo(sortedMapOf()) { _, accumulator, element -> maxOf(accumulator, element, compareByAvgScore) }
```

Cách này là tốt nhất cho đến hiện tại :), nó sử dụng functional style, và tốt về mặt thời gian và không gian.

- Bản chất, `groupingBy` sẽ tạo và return 1 object `Grouping` để lưu trữ `Iterator` và `Key Selector` để thực hiện việc `reduce`/`aggregate` sau đó.
    ```kotlin
    @SinceKotlin("1.1") public interface Grouping<T, out K> {
        fun sourceIterator(): Iterator<T>
        fun keyOf(element: T): K
    }
    ```
    `Grouping` không thực hiện việc duyệt, `reduce`/`aggregate` ngay lập tức, mà nó chỉ lữu trữ những cái cần thiết để thực hiện việc `aggregate` sau này.
    Đó là cơ chế **LAZY**, tương tự như `Sequence` của Koltin, `Stream` của Java, `Observable` của RxJava, `Flow` của Kotlin Coroutines, ...

- Sau đó, `reduceTo` sẽ duyệt qua `Grouping` object, và thực hiện việc `reduce`/`aggregate` trên từng `Group` xác định bởi `Key Selector`.
Hàm `reduceTo` trên `Grouping` có cơ chế khá giống trên `Iterable`, nhưng nó không thực thi `operation` trên toàn bộ `Iterable`,
mà nó thực thi `operation` trên từng `Group` xác định bởi `Key Selector`.
Bản chất như sau (không giống source của stdlib 100%, vì lược bỏ những thứ không cần thiết):

```kotlin
inline fun <S, T : S, K, M : MutableMap<in K, S>> Grouping<T, K>.reduceTo(
  destination: M,
  operation: (key: K, accumulator: S, element: T) -> S
): M {
  for (element in sourceIterator()) {
    val key = keyOf(element)
    val accumulator = destination[key]
    destination[key] = if (accumulator == null && !destination.containsKey(key)) {
      element
    } else {
      operation(key, accumulator as S, element)
    }
  }
  return destination
}
```

------------------------------------------

Follow tôi, chúng tôi https://rx-mobile-team.github.io/profile/ để có thêm nhiều kiến thức về lập trình, không chỉ giới hạn
ở Mobile (Android/iOS/Flutter) mà có cả Functional Programming, Reactive Programming, Data Structures, Algorithms, ...
Những kiến thức chia sẻ ở đây, rất ít các Senior Dev và vân..vân.. chia sẻ cho các bạn đâu.
