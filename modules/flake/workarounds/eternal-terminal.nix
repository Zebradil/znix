_: {
  znix.workarounds.eternal-terminal = {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    reason = "abseil-cpp 20260817 requires C++20 while ET 7.0.0 pins C++17; mirrors NixOS/nixpkgs#569401.";
    override = _pkgs: old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace CMakeLists.txt \
          --replace-fail 'set(CMAKE_CXX_STANDARD 17)' 'set(CMAKE_CXX_STANDARD 20)'
        substituteInPlace external_imported/ThreadPool/ThreadPool.h \
          --replace-fail '#include <stdexcept>' $'#include <stdexcept>\n#include <type_traits>' \
          --replace-fail 'std::result_of<F(Args...)>' 'std::invoke_result<F, Args...>'
      '';
    };
  };
}
