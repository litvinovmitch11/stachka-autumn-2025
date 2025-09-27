#include <iostream>
#include <chrono>

int counter = 0;

int fib(int n) {
    counter++;
    if (n < 2) {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}

int main() {
    auto start = std::chrono::high_resolution_clock::now();
    int result = fib(42);
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = end - start;
    std::cout << "C++ Result: " << result << ", Time: " << duration.count() << "s" << std::endl;
    std::cout << "Total function calls: " <<  counter << std::endl;
}
