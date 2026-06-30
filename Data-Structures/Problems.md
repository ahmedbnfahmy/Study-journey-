# Data Structures — Problems

| # | Problem | Description | Input | Output |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Find Largest Number in Array | Given an array of numbers, find and return the largest number. | `[1, 5, 3, 9]` | `9` |
| 2 | Binary Search in Sorted Array | Given a sorted array of unique integers, find the index of a target integer using binary search O(log n). | `[1, 3, 5, 7, 9]`, `5` | `2` |
| 3 | Sort Array in Ascending Order | Sort an array of integers in ascending order O(n log n) time, minimal space. | `[5, 2, 3, 1]` | `[1, 2, 3, 5]` |

---

## 1. Find Largest Number in Array

```javascript
function findLargestNumber(arr) {
  let largest = arr[0];
  for (let i = 1; i < arr.length; i++) {
    if (arr[i] > largest) largest = arr[i];
  }
  return largest;
}
```

---

## 2. Binary Search in Sorted Array

```javascript
function binarySearch(nums, target) {
  let left = 0, right = nums.length - 1;
  while (left <= right) {
    const mid = Math.floor((left + right) / 2);
    if (nums[mid] === target) return mid;
    else if (nums[mid] < target) left = mid + 1;
    else right = mid - 1;
  }
  return -1;
}
```

---

## 3. Sort Array in Ascending Order

```javascript
function sortArray(nums) {
  quickSort(nums, 0, nums.length - 1);
  return nums;
}

function quickSort(nums, left, right) {
  if (left < right) {
    const pivotIndex = partition(nums, left, right);
    quickSort(nums, left, pivotIndex - 1);
    quickSort(nums, pivotIndex + 1, right);
  }
}

function partition(nums, left, right) {
  const pivot = nums[right];
  let i = left - 1;
  for (let j = left; j < right; j++) {
    if (nums[j] <= pivot) {
      i++;
      [nums[i], nums[j]] = [nums[j], nums[i]];
    }
  }
  [nums[i + 1], nums[right]] = [nums[right], nums[i + 1]];
  return i + 1;
}
```
