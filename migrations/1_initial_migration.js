const GuestBook = artifacts.require("GuestBook");

module.exports = function (deployer) {
  deployer.deploy(GuestBook);
};
