pragma solidity 0.4.17;

library IdeaUint {

    function add(uint a, uint b) constant internal returns (uint result) {
        uint c = a + b;

        assert(c >= a);

        return c;
    }

    function sub(uint a, uint b) constant internal returns (uint result) {
        uint c = a - b;

        assert(b <= a);

        return c;
    }

    function mul(uint a, uint b) constant internal returns (uint result) {
        uint c = a * b;

        assert(a == 0 || c / a == b);

        return c;
    }

    function div(uint a, uint b) constant internal returns (uint result) {
        uint c = a / b;

        return c;
    }
}