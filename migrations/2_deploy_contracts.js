// const SafeMath = artifacts.require("SafeMath");
const Exchange = artifacts.require("Exchange");

module.exports = function (deployer) {
    deployer.deploy(Exchange);
};
