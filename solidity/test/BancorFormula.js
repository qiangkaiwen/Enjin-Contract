/* global artifacts, contract, it, before, assert, web3 */
/* eslint-disable prefer-reflect, no-loop-func */

let constants = require('./helpers/FormulaConstants.js');
let TestBancorFormula = artifacts.require('./helpers/TestBancorFormula.sol');
const utils = require('./helpers/Utils');

let formula;

contract('BancorFormula', () => {
    before(async () => {
        formula = await TestBancorFormula.new();
    });

    let MAX_NUMERATOR = web3.toBigNumber(2).toPower(256 - constants.MAX_PRECISION).minus(1);

    it('Verify function ln legal input', async () => {
        try {
            await formula.testLn.call(MAX_NUMERATOR, 1);
        }
        catch (error) {
            assert(false, `Function ln(${MAX_NUMERATOR}, 1) failed when it should have passed`);
        }
    });

    it('Verify function ln illegal input', async () => {
        try {
            await formula.testLn.call(MAX_NUMERATOR.plus(1), 1);
            assert(false, `Function ln(${MAX_NUMERATOR.plus(1)}, 1) passed when it should have failed`);
        }
        catch (error) {
            return utils.ensureException(error);
        }
    });

    for (let precision = constants.MIN_PRECISION; precision <= constants.MAX_PRECISION; precision++) {
        let maxExp = web3.toBigNumber(constants.maxExpArray[precision]);
        let maxVal = web3.toBigNumber(constants.maxValArray[precision]);

        it('Verify function fixedExp legal input', async () => {
            let retVal = await formula.testFixedExp.call(maxExp, precision);
            assert(retVal.equals(maxVal), `Result of function fixedExp(${maxExp}, ${precision}) is wrong`);
        });

        it('Verify function fixedExp illegal input', async () => {
            let retVal = await formula.testFixedExp.call(maxExp.plus(1), precision);
            assert(retVal.lessThan(maxVal), `Result of function fixedExp(${maxExp.plus(1)}, ${precision}) indicates that maxExpArray[${precision}] is wrong`);
        });
    }
});
