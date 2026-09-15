// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BridgeHelper} from "../src/BridgeHelper.sol";

interface Vm {
    function etch(address target, bytes calldata code) external;
    function deal(address account, uint256 balance) external;
    function prank(address caller) external;
}

// Local doubles for the documented G token and canonical sender. The CLI test
// also installs this code on Anvil at the addresses used by the actual recipes.
contract MockG {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;
    bool public failTransfer;
    bool public failApproval;

    function mint(address recipient, uint256 amount) external { balanceOf[recipient] += amount; }
    function setFailures(bool transferFailure, bool approvalFailure) external {
        failTransfer = transferFailure;
        failApproval = approvalFailure;
    }
    function setNonce(address owner, uint256 nonce) external { nonces[owner] = nonce; }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (failApproval) return false;
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (failTransfer) return false;
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline,
        uint8 v, bytes32 r, bytes32 s) external
    {
        require(block.timestamp <= deadline, "expired");
        bytes32 domain = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("Gravity"), keccak256("1"), block.chainid, address(this)
        ));
        bytes32 message = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner, spender, value, nonces[owner]++, deadline
        ));
        address signer = ecrecover(keccak256(abi.encodePacked(hex"1901", domain, message)), v, r, s);
        require(signer != address(0) && signer == owner, "invalid permit");
        allowance[owner][spender] = value;
    }
}

contract MockBridge {
    MockG constant G = MockG(0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649);
    uint256 public constant FEE = 1e15;
    mapping(address => uint256) public credited;
    bool public failBridge;

    function setFailure(bool failure) external { failBridge = failure; }
    function calculateBridgeFee(uint256, address) external pure returns (uint256) { return FEE; }

    function bridgeToGravity(uint256 amount, address recipient) public payable returns (uint128) {
        require(!failBridge, "bridge unavailable");
        require(amount > 0 && recipient != address(0), "invalid destination or amount");
        require(msg.value >= FEE && msg.value <= 2 * FEE, "invalid fee");
        require(G.transferFrom(msg.sender, address(this), amount), "transfer failed");
        credited[recipient] += amount;
        return 1;
    }

    function bridgeToGravityWithPermit(uint256 amount, address recipient, uint256 deadline,
        uint8 v, bytes32 r, bytes32 s) external payable returns (uint128)
    {
        G.permit(msg.sender, address(this), amount, deadline, v, r, s);
        return bridgeToGravity(amount, recipient);
    }
}

contract BridgeExamplesTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    MockG constant G = MockG(0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649);
    MockBridge constant SENDER = MockBridge(0xE82c61Ac9Ec2041b493118051afa4F18a55dC876);
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    address constant RECIPIENT = address(0xCAFE);
    uint256 constant AMOUNT = 100e18;
    uint256 constant FEE = 1e15;
    BridgeHelper helper;

    function setUp() external {
        vm.etch(address(G), type(MockG).runtimeCode);
        vm.etch(address(SENDER), type(MockBridge).runtimeCode);
        helper = new BridgeHelper();
        G.mint(ALICE, AMOUNT);
        vm.deal(ALICE, 1 ether);
        vm.deal(BOB, 1 ether);
        vm.prank(ALICE);
        G.approve(address(helper), AMOUNT);
    }

    function callBridge(address caller, uint256 fee) private returns (bool ok) {
        vm.prank(caller);
        (ok,) = address(helper).call{value: fee}(abi.encodeCall(helper.bridge, (AMOUNT, RECIPIENT)));
    }

    function assertUnchanged() private view {
        require(G.balanceOf(ALICE) == AMOUNT, "caller lost G");
        require(G.allowance(ALICE, address(helper)) == AMOUNT, "caller approval changed");
        require(G.allowance(address(helper), address(SENDER)) == 0, "bridge approval left behind");
        require(SENDER.credited(RECIPIENT) == 0, "unexpected bridge credit");
        require(address(helper).balance == 0, "ETH retained");
    }

    function testCallerFundsBridgeWithoutSpendingExistingDeposit() external {
        G.mint(address(helper), 7e18);
        require(callBridge(ALICE, FEE), "bridge failed");
        require(G.balanceOf(ALICE) == 0, "caller not charged");
        require(G.balanceOf(address(helper)) == 7e18, "existing deposit spent");
        require(SENDER.credited(RECIPIENT) == AMOUNT, "wrong recipient credit");
        require(G.allowance(address(helper), address(SENDER)) == 0, "unused bridge allowance");
        require(address(helper).balance == 0, "ETH retained");
        require(address(SENDER).balance == FEE, "wrong forwarded fee");
    }

    function testOtherCallerCannotSpendVictimDeposit() external {
        G.mint(address(helper), AMOUNT);
        require(!callBridge(BOB, FEE), "stole victim deposit");
        require(G.balanceOf(address(helper)) == AMOUNT, "deposit consumed");
        assertUnchanged();
    }

    function testRejectsUnderpayment() external {
        require(!callBridge(ALICE, FEE - 1), "accepted underpayment");
        assertUnchanged();
    }

    function testRejectsOverpayment() external {
        // A prefunded helper must still reject excess ETH, rather than letting
        // a downstream insufficient-balance failure mask a broken fee check.
        G.mint(address(helper), AMOUNT);
        require(!callBridge(ALICE, FEE + 1), "accepted overpayment");
        require(G.balanceOf(address(helper)) == AMOUNT, "existing deposit changed");
        assertUnchanged();
    }

    function testCallerMustApproveEvenWhenHelperHasFunds() external {
        G.mint(address(helper), AMOUNT);
        vm.prank(ALICE);
        G.approve(address(helper), 0);
        require(!callBridge(ALICE, FEE), "bridged without caller approval");
        require(G.balanceOf(ALICE) == AMOUNT, "caller lost G");
        require(G.balanceOf(address(helper)) == AMOUNT, "existing deposit spent");
        require(SENDER.credited(RECIPIENT) == 0, "unexpected bridge credit");
    }

    function testBridgeFailureRollsBackTransferAndApproval() external {
        SENDER.setFailure(true);
        require(!callBridge(ALICE, FEE), "accepted failed bridge");
        assertUnchanged();
    }

    function testTransferFalseReverts() external {
        G.setFailures(true, false);
        require(!callBridge(ALICE, FEE), "accepted failed transfer");
        assertUnchanged();
    }

    function testApprovalFalseRollsBackTransfer() external {
        G.setFailures(false, true);
        require(!callBridge(ALICE, FEE), "accepted failed approval");
        assertUnchanged();
    }
}
