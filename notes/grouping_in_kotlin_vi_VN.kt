import java.util.*

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
  check(solution1(students) == output)
  check(solution2(students) == output)
  check(solution3(students) == output)
}
