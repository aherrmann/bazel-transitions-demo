#include <iostream>
#include <fstream>
#include "tools/cpp/runfiles/runfiles.h"

void edition_function();

int main(int argc, char **argv) {
        edition_function();

        using bazel::tools::cpp::runfiles::Runfiles;

        std::string error;
        std::unique_ptr<Runfiles> runfiles(Runfiles::Create(argv[0], &error));
        if (runfiles == nullptr) {
                std::cerr << "Failed to create runfiles: " << error << "\n";
                std::exit(1);
        }
        std::string path = runfiles->Rlocation("transitions-demo/app/data.txt");
        std::ifstream data(path);
        if (!data.is_open()) {
                std::cerr << "Failed to open data file: " << path << "\n";
                std::exit(1);
        }
        std::cerr << "Data file: " << data.rdbuf() << "\n";
}
