```
## Two Sum

The Two Sum problem asks us to find two indices in an array whose values add up to a given target.
const nums = [2, 7, 11, 15];
const target = 9;
```

### How the hash map way works

- We use a hash map to store values we have already seen.
- For each number, we check whether its complement already exists in the map.
- If it does, we found the pair.
- If not, we save the current value with its index for later.

Time complexity: O(n)
Space complexity: O(n)

1.HashMap approach

```typescript
function twoSum(nums: number[], target: number): number[] {
  const seen = new Map<number, number>();

  for (let i = 0; i < nums.length; i++) {
    const complement = target - nums[i];

    if (seen.has(complement)) {
      return [seen.get(complement)!, i];
    }

    seen.set(nums[i], i);
  }

  return [];
}
```

### 2) Brute force approach

```ts
function twoSumBruteForce(nums: number[], target: number): number[] {
  for (let i = 0; i < nums.length; i++) {
    for (let j = i + 1; j < nums.length; j++) {
      if (nums[i] + nums[j] === target) {
        return [i, j];
      }
    }
  }

  return [];
}
```

This approach checks every pair, so it is slower.

Time complexity: O(n^2)
Space complexity: O(1)

### 3) Two-pointer approach for a sorted array

```ts
function twoSumSorted(nums: number[], target: number): number[] {
  let left = 0;
  let right = nums.length - 1;

  while (left < right) {
    const currentSum = nums[left] + nums[right];

    if (currentSum === target) {
      return [left + 1, right + 1];
    } else if (currentSum < target) {
      left++;
    } else {
      right--;
    }
  }

  return [];
}
```

This version works only when the array is already sorted.

Time complexity: O(n)
Space complexity: O(1)
