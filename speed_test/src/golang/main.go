package main

import (
	"fmt"
	"time"
)

var counter int

func fib(n int) int {
	counter++
	if n < 2 {
		return n
	}
	return fib(n-1) + fib(n-2)
}

func main() {
	counter = 0
	start := time.Now()
	result := fib(42)
	duration := time.Since(start)
	
	fmt.Printf("Go Result: %d, Time: %s\n", result, duration)
	fmt.Printf("Total function calls: %d\n", counter)
}
