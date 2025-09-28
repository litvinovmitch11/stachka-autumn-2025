package main

import (
	"fmt"
	"time"
)

func fib(n int) int {
	if n < 2 {
		return n
	}
	return fib(n-1) + fib(n-2)
}

func main() {
	start := time.Now()
	result := fib(42)
	duration := time.Since(start)
	fmt.Printf("Go Result: %d, Time: %s\n", result, duration)
}
