#!/usr/bin/env python3
"""Run documented Solidity and Bash examples with Foundry on a disposable chain.

Requires forge, cast, anvil, and Solidity 0.8.30 (set SOLC to its executable).
No external RPCs are used. Build products and a generated test keystore are
created in a temporary directory and removed after the run.
"""

import json
import os
from pathlib import Path
import re
import secrets
import shlex
import shutil
import socket
import subprocess
import tempfile
import time
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "skills/gravity/examples"
G = "0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649"
SENDER = "0xE82c61Ac9Ec2041b493118051afa4F18a55dC876"
RECIPIENT = "0x000000000000000000000000000000000000cafE"
AMOUNT = 100 * 10**18


def run(*args, **kwargs):
    result = subprocess.run(args, text=True, capture_output=True, timeout=120, **kwargs)
    if result.returncode:
        # Never print argv: wallet import includes a disposable private key.
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout.strip()


def rpc(url, method, params):
    data = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    request = Request(url, data=data, headers={"Content-Type": "application/json"})
    with urlopen(request, timeout=5) as response:
        result = json.load(response)
    if "error" in result:
        raise RuntimeError(result["error"])
    return result["result"]


def check_shell_recipes(work, markdown):
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    url = f"http://127.0.0.1:{port}"
    process = subprocess.Popen(
        ["anvil", "--host", "127.0.0.1", "--port", str(port), "--chain-id", "1", "--silent"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(50):
            try:
                accounts = rpc(url, "eth_accounts", [])
                break
            except OSError:
                if process.poll() is not None:
                    raise RuntimeError("Anvil exited before startup")
                time.sleep(0.1)
        else:
            raise RuntimeError("Anvil did not start")

        for name, address in [("MockG", G), ("MockBridge", SENDER)]:
            artifact = json.loads((work / f"out/BridgeExamples.t.sol/{name}.json").read_text())
            code = artifact["deployedBytecode"]["object"]
            rpc(url, "anvil_setCode", [address, code])

        keydir = work / "test keystores"
        keydir.mkdir()
        run("cast", "wallet", "import", "bridge-test", "--keystore-dir", str(keydir),
            "--unsafe-password", "test-only", "--private-key", "0x" + secrets.token_hex(32))
        wallet = ["--keystore", str(keydir / "bridge-test"), "--password", "test-only"]
        owner = run("cast", "wallet", "address", *wallet)
        rpc(url, "anvil_setBalance", [owner, hex(10**20)])

        def send(address, signature, *args):
            run("cast", "send", address, signature, *map(str, args),
                "--rpc-url", url, "--from", accounts[0], "--unlocked")

        def read(address, signature, *args):
            raw = run("cast", "call", address, signature, *map(str, args), "--rpc-url", url)
            return int(raw, 16)

        recipes = re.findall(r"```bash\n(.*?)```", markdown, re.S)
        assert len(recipes) == 2
        for index, recipe in enumerate(recipes):
            send(G, "mint(address,uint256)", owner, AMOUNT)
            # A nonce larger than JS's exact integer range catches both cast's
            # scientific annotation and lossy JSON-number handling.
            nonce = 10**18 + 1
            send(G, "setNonce(address,uint256)", owner, nonce)
            recipe = re.sub(r"^RPC=.*$", f"RPC={url}", recipe, flags=re.M)
            recipe = recipe.replace("0xYourGravityAddress", RECIPIENT)
            recipe = recipe.replace("--account my-keystore", shlex.join(wallet))
            script = work / f"recipe-{index}.bash"
            script.write_text(recipe)
            run("bash", str(script))
            assert read(G, "balanceOf(address)", owner) == 0
            assert read(G, "allowance(address,address)", owner, SENDER) == 0
            assert read(SENDER, "credited(address)", RECIPIENT) == AMOUNT * (index + 1)
            assert read(G, "nonces(address)", owner) == nonce + index
            print(f"Bash recipe {index + 1}: bridge credited recipient; fee and signature valid")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def main():
    markdown = (EXAMPLES / "bridge-g-from-ethereum.md").read_text()
    with tempfile.TemporaryDirectory(prefix="gravity-example-check-") as directory:
        work = Path(directory)
        (work / "src").mkdir()
        (work / "test").mkdir()
        for source in EXAMPLES.glob("*.sol"):
            shutil.copy(source, work / "src" / source.name)
        helper, = re.findall(r"```solidity\n(.*?)```", markdown, re.S)
        (work / "src/BridgeHelper.sol").write_text(helper)
        shutil.copy(ROOT / "tests/BridgeExamples.t.sol", work / "test/BridgeExamples.t.sol")
        print(run("forge", "test", "--root", str(work), "--use", os.environ.get("SOLC", "0.8.30"),
                  "--offline", "-vv"))
        check_shell_recipes(work, markdown)


if __name__ == "__main__":
    main()
