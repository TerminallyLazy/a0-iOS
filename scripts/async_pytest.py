"""Run this bounded suite's coroutine tests without adding a dependency to the image.
No async fixtures or persistent event-loop semantics are provided.
"""
import asyncio
import inspect

def pytest_configure(config):
    config.addinivalue_line("markers", "asyncio: coroutine executed with asyncio.run in isolated contract runner")

def pytest_pyfunc_call(pyfuncitem):
    if inspect.iscoroutinefunction(pyfuncitem.obj):
        kwargs = {name: pyfuncitem.funcargs[name] for name in pyfuncitem._fixtureinfo.argnames}
        asyncio.run(pyfuncitem.obj(**kwargs))
        return True
