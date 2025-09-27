package main

import (
	"fmt"
	"sort"
)

type ComplexStruct struct {
	Data    []string
	Mapping map[int]string
}

func (c *ComplexStruct) AddData(item string) {
	c.Data = append(c.Data, item)
	if c.Mapping == nil {
		c.Mapping = make(map[int]string)
	}
	c.Mapping[len(c.Data)] = item
}

func (c *ComplexStruct) ProcessData() {
	sort.Strings(c.Data)
	for _, item := range c.Data {
		fmt.Printf("Processed: %s\n", item)
	}
}

func main() {
	obj := &ComplexStruct{}
	obj.AddData("Hello")
	obj.AddData("World")
	obj.AddData("From")
	obj.AddData("Complex")
	obj.AddData("Go")
	obj.ProcessData()
}
