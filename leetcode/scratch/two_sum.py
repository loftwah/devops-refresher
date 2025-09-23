from typing import List


class Solution:
    def twoSum(self, nums: List[int], target: int) -> List[int]:
        seen: dict[int, int] = {}
        for index, value in enumerate(nums):
            needed = target - value
            if needed in seen:
                return [seen[needed], index]
            seen[value] = index
        raise ValueError("No solution found")


def run_demo() -> None:
    solver = Solution()
    cases = [
        ([2, 7, 11, 15], 9),
        ([3, 3], 6),
        ([-3, 4, 3, 90], 0),
        ([5, 1, 4, 2, 8], 10),
    ]
    for nums, target in cases:
        result = solver.twoSum(nums, target)
        print(f"nums={nums}, target={target} -> indices={result}")


if __name__ == "__main__":
    run_demo()
