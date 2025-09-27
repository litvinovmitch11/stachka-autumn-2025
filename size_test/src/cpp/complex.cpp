#include <iostream>
#include <vector>
#include <string>
#include <map>
#include <algorithm>

class ComplexClass {
private:
    std::vector<std::string> data;
    std::map<int, std::string> mapping;
    
public:
    void addData(const std::string& item) {
        data.push_back(item);
        mapping[data.size()] = item;
    }
    
    void processData() {
        std::sort(data.begin(), data.end());
        for (const auto& item : data) {
            std::cout << "Processed: " << item << std::endl;
        }
    }
};

int main() {
    ComplexClass obj;
    obj.addData("Hello");
    obj.addData("World");
    obj.addData("From");
    obj.addData("Complex");
    obj.addData("C++");
    obj.processData();
    return 0;
}
