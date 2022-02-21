from threading import Thread

class Worker(Thread):
    def __init__(
        self, 
        func: any,
        *args: any,
        **kargs: any
    ) -> None:
        Thread.__init__(self)
        self.func = func
        self.args = args
        self.kargs = kargs

        self.result = None

    def run(self):
        try:
            self.result = self.func(*self.args, **self.kargs)
        except Exception as e:
            print(e)
            self.result = None
        