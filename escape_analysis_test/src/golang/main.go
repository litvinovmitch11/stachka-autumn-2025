package main

//go:noinline
func stackExample() int {
    // Эта переменная должна остаться в стеке
    var data [100]int
    for i := range data {
        data[i] = i
    }
    return data[42]  // Возвращаем только значение
}

//go:noinline
func heapExample() *[100]int {
    // Эта переменная должна уйти в кучу
    data := new([100]int)
    for i := range data {
        data[i] = i
    }
    return data  // Возвращаем указатель - убегает в кучу
}

//go:noinline
func escapeExample() *int {
    // Локальная переменная должна уйти в кучу
    x := 42
    return &x  // Возвращаем адрес - убегает в кучу
}

func main() {
    // Вызываем все функции для анализа
    _ = stackExample()
    _ = heapExample()
    _ = escapeExample()
}
