// SPDX-License-Identifier: MIT
pragma solidity = 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/*
 * Fairy核心接口
 */
interface IFairyCore {
    // 为指定TokenId的Fairy，设置TokenURI，只允许控制者执行设置
    function setTokenURI(uint256 tokenId, string memory tokenUri) external;

    // 铸造Money，只允许控制者执行铸造，可以铸造一个Fairy, 并从Fairy核心合约地址向目标地址转账Fairy
    function mintOnce(address to, uint256 tokenId) external;
}

/*
 * Fairy属性接口
 */
interface IFairyAttrs {
    // 获取指定TokenId的Fairy的指定属性的值
    function getAttr(uint256 tokenId, uint256 index) external view returns (uint256);

    // 设置指定TokenId的Fairy的指定属性的值
    function setAttr(uint256 tokenId, uint256 index, uint256 value) external;
}

/*
 * Fairy控制接口
 */
interface IFairyCtrl {
    // 判断指定TokenId的Fairy是否属于指定账户
    function isOwns(address account, uint256 tokenId) external view returns (bool);

    // 获取指定TokenId的Fairy的当前繁殖次数
    function currentBreedingCount(uint256 tokenId) external view returns (uint256);

    // 铸造一个指定等级和繁殖次数的Fairy，并转账到目标外部地址，返回铸造Fairy的TokenId
    function mintSpecifyFairy(address to, uint256 level, uint256 breeding_count) external returns (uint256);

    // 繁殖一个Fairy，并转账到目标外部地址，返回下一代Fairy的TokenId
    function breedFairy(address to, uint256 fatherId, uint256 motherId, uint256 level) external returns (uint256);
}

/*
 * Sprite核心接口
 */
interface ISpriteCore {
    // 提现Sprite，只允许Sprite控制合约提现，从Sprite核心合约地址向目标地址转账Sprite
    function withDraw(address to, uint256 amount) external;
}

/*
 * Money核心接口
 */
interface IMoneyCore {
    // 铸造Money，只允许Money控制合约铸造，从Money核心合约地址向目标地址转账Money
    function mint(address to, uint256 amount) external;

    // 提现Money，只允许Money控制合约提现，从Money核心合约地址向目标地址转账Money
    function withDraw(address to, uint256 amount) external;
}

/*
 * 基本合约
 */
contract Base is Ownable, AccessControl, Pausable {
    bytes32 internal constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address private _tokens_owner;
    
    // 调试日志事件
    event DebugLog(string info);

    // 检查指定地址是否是合约地址
    modifier isContract(address account) {
        require(Address.isContract(account), 'Caller is not a contract address');
        _;
    }

    // 检查指定地址是否是外部地址
    modifier isExternal(address account) {
        require(!Address.isContract(account), 'Caller is not a external address');
        _;
    }

    // 基本合约的构造函数
    constructor() {
        //在合约构造时，为所有者设置默认管理员角色，只有默认管理员可以动态授予和撤销角色
        _setupRole(DEFAULT_ADMIN_ROLE, owner());
        grantRole(MANAGER_ROLE, owner());
        _tokens_owner = owner();
    }

    function getTokensOwner() public view returns (address) {
        return _tokens_owner;
    }

    function setTokensOwner(address tokens_owner) public onlyRole(MANAGER_ROLE) {
        _tokens_owner = tokens_owner;
    }

    // 打印调试日志
    function debugLog(string memory info) internal {
        emit DebugLog(info);
    }
}

/*
 * 工具库
 */
library Utils {
    // 通用验证签名，明文需要调用abi.encodePacked(...)获取message
    function validSign(address from, bytes memory message, bytes memory sign) internal pure returns (bool) {
        bytes32 _message = ECDSA.toEthSignedMessageHash(keccak256(message));
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(_message, sign);

        if (error != ECDSA.RecoverError.NoError) {
            //验证签名错误
            return false;
        }

        if (from != recovered) {
            //验证签名地址错误
            return false;
        }

        return true;
    }

    // 将地址转换为uint160
    function addressToUint160(address account) internal pure returns (uint160) {
        return uint160(account);
    }

    // 将uint160转换为地址
    function uint160ToAddress(uint160 value) internal pure returns (address) {
        return address(value);
    }

    // 将地址转换为uint256
    function addressToUint256(address account) internal pure returns (uint256) {
        return uint256(uint160(account));
    }

    // 将uint256转换为字符串
    function uint256ToString(uint256 value) internal pure returns (string memory) {
        return bytesToString(abi.encodePacked(value));
    }

    // 将指定地址转换为字符串
    function addressToString(address account) internal pure returns (string memory) {
        return bytesToString(abi.encodePacked(account));
    }

    // 将指定地址转换为字符串
    function bytesToString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}