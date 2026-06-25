{...}: {
  hostSpec.services = {
    ollama = {
      enable = true;
      loadModels = [
        "gemma4:e4b"
        "gemma4:e2b"
        "codegemma:7b-code-q4_K_M"
      ];
    };
  };
}
