import sys

from src.server import Server

def main() -> None:
    try:
        server = Server()
    except Exception as e:
        print(f'Error \n{e}')
        sys.exit(1)
    server.start()

if __name__ == '__main__':
    main()