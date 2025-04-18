import http.server
import socketserver
import os
import webbrowser
from threading import Timer

PORT = 8080

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.path.dirname(os.path.abspath(__file__)), **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()
        
    def do_GET(self):
        # Redirect root and certain paths to index.html
        if self.path == '/' or self.path == '/index' or self.path == '/index.htm':
            self.path = '/index.html'
        return super().do_GET()

def open_browser():
    """Open browser after server has started"""
    webbrowser.open(f'http://localhost:{PORT}')

if __name__ == "__main__":
    print(f"Starting server at http://localhost:{PORT}")
    print(f"Press Ctrl+C to quit")
    
    # Open browser after a short delay
    Timer(1.5, open_browser).start()
    
    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")
            httpd.server_close() 