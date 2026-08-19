## 9. Palindrome Number

### Problem

Given an integer `x`, return `true` if `x` is a palindrome, and `false` otherwise.

### Example 1

```ts
Input: x = 121
Output: true
```

### Example 2

```ts
Input: x = -121
Output: false
```

### Example 3

```ts
Input: x = 10
Output: false
```

### Constraints

- `-231 <= x <= 231 - 1`

### Solution

```ts
function isPalindrome(x: number): boolean {
  if (x < 0 || (x % 10 === 0 && x !== 0)) return false;

  let reversedHalf = 0;

  while (x > reversedHalf) {
    reversedHalf = reversedHalf * 10 + (x % 10);
    x = Math.floor(x / 10);
  }

  return x === reversedHalf || x === Math.floor(reversedHalf / 10);
}
```

### Explanation

- If the number is negative, it cannot be a palindrome.
- If the number ends with `0` and is not `0`, it cannot be a palindrome.
- We reverse only half of the number to avoid extra memory.
- If the remaining half matches the reversed half, the number is a palindrome.

### Time Complexity

- O(log n)

### Space Complexity

- O(1)
