#include <iostream>
#include <string>
#include <sstream>
#include <cstring>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/socket.h>

constexpr int PORT = 8080;
constexpr int BACKLOG = 10;
constexpr int BUFFER_SIZE = 4096;

std::string buildResponse(int statusCode, const std::string& statusText,
                          const std::string& body, const std::string& contentType = "application/json") {
    std::ostringstream oss;
    oss << "HTTP/1.1 " << statusCode << " " << statusText << "\r\n"
        << "Content-Type: " << contentType << "\r\n"
        << "Content-Length: " << body.size() << "\r\n"
        << "Connection: close\r\n"
        << "\r\n"
        << body;
    return oss.str();
}

void handleClient(int clientFd) {
    char buffer[BUFFER_SIZE] = {};
    ssize_t bytesRead = read(clientFd, buffer, BUFFER_SIZE - 1);
    if (bytesRead <= 0) {
        close(clientFd);
        return;
    }

    std::string request(buffer, bytesRead);
    std::string method, path, version;
    std::istringstream reqStream(request);
    reqStream >> method >> path >> version;

    std::string response;
    if (path == "/health" || path == "/healthz") {
        response = buildResponse(200, "OK", R"({"status":"healthy","service":"aksazuregitopslab"})");
    } else if (path == "/") {
        response = buildResponse(200, "OK", R"({"message":"Hello from AKS!","version":"1.0.0"})");
    } else {
        response = buildResponse(404, "Not Found", R"({"error":"not found"})");
    }

    write(clientFd, response.c_str(), response.size());
    close(clientFd);
}

int main() {
    int serverFd = socket(AF_INET, SOCK_STREAM, 0);
    if (serverFd < 0) { perror("socket"); return 1; }

    int opt = 1;
    setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(PORT);

    if (bind(serverFd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        perror("bind"); return 1;
    }
    if (listen(serverFd, BACKLOG) < 0) { perror("listen"); return 1; }

    std::cout << "Server listening on port " << PORT << std::endl;

    while (true) {
        sockaddr_in clientAddr{};
        socklen_t clientLen = sizeof(clientAddr);
        int clientFd = accept(serverFd, reinterpret_cast<sockaddr*>(&clientAddr), &clientLen);
        if (clientFd < 0) { perror("accept"); continue; }
        handleClient(clientFd);
    }

    close(serverFd);
    return 0;
}
