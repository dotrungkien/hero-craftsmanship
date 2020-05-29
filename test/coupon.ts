import {
  Client,
  Result,
  Provider,
  ProviderRegistry,
} from '@blockstack/clarity';

import { expect } from 'chai';

import {
  unwrapAddress,
  createCoupon,
  getTotalCode,
  checkCouponValid,
  checkCouponDiscount,
  ownerOf,
  isOwner,
  checkCouponUsed,
  transferCoupon,
  useCoupon,
} from './helpers';

describe('coupon contract', () => {
  const contractName = 'coupon';
  const deployer = 'SP2R8MPF1WYDQD2AZY9GCZRAVG8JYZ25FNB8X45EK';
  const couponCreator = 'SP3GHS3JVCBPW4K0HJ95VCKZ6EDWV08YMZ85XQGN0';
  const userA = 'SP13VF98697SCY877MECN9CESFN5VHK8P744DB0TY';
  const userB = 'SP33AV3DHD6P9XAPYKJ6JTEF83QRZXX6Q5YMVWS5X';
  const userC = 'SP3DWF717EZRH2M4S16TZDVNZPWT7DG95ZK5YAS69';

  let provider: Provider;
  let client: Client;

  before(async () => {
    provider = await ProviderRegistry.createProvider();
    client = new Client(`${deployer}.${contractName}`, contractName, provider);
  });

  it('make sure contract has valid syntax', async () => {
    await client.checkContract();
    await client.deployContract();
  });

  describe('Check initialize state', () => {
    it('no coupon is created yet', async () => {
      const valid = await checkCouponValid(client, 'u1');
      expect(valid).equal(false);
    });
  });

  describe('create some coupon', () => {
    before(async () => {
      await createCoupon(client, 'u10');
      await createCoupon(client, 'u20');
      await createCoupon(client, 'u30');
    });

    it('total code is 3', async () => {
      let totalCode = await getTotalCode(client);
      expect(totalCode).equal(3);
    });

    it('coupon code u1 now became valid', async () => {
      let valid = await checkCouponValid(client, 'u1');
      expect(valid).equal(true);
    });

    it('coupon u1 belongs to coupon creator', async () => {
      let owner = await ownerOf(client, 'u1');
      expect(owner).equal(couponCreator);
    });

    it('coupon u2 belongs to coupon creator', async () => {
      let owner = await ownerOf(client, 'u2');
      expect(owner).equal(couponCreator);
    });

    it('coupon u3 belongs to coupon creator', async () => {
      let owner = await ownerOf(client, 'u3');
      expect(owner).equal(couponCreator);
    });

    it('coupon u1 is not used yet', async () => {
      let used = await checkCouponUsed(client, 'u1');
      expect(used).equal(false);
    });

    it('coupon u1 is 10% discount', async () => {
      let discount = await checkCouponDiscount(client, 'u1');
      expect(discount).equal(10);
    });

    describe('transfer coupon', () => {
      before(async () => {
        await transferCoupon(client, couponCreator, userA, 'u1');
        await transferCoupon(client, couponCreator, userB, 'u2');
        await transferCoupon(client, userB, userC, 'u2');
      });

      it('coupon u2 now belongs to userA', async () => {
        let receipt = await isOwner(client, userA, 'u1');
        // console.log({ receipt });
      });

      it('coupon u3 now belongs to userC', async () => {
        let receipt = await isOwner(client, userC, 'u2');
        // console.log({ receipt });
      });
    });

    describe('use coupon', () => {
      before(async () => {
        await useCoupon(client, couponCreator, 'u3');
      });

      it('other cannot use coupon', async () => {
        let receipt = await useCoupon(client, userA, 'u3');
        expect(receipt.success).equal(false);
      });

      it('coupon u3 belongs to coupon creator', async () => {
        let receipt = await isOwner(client, couponCreator, 'u3');
        expect(Result.unwrap(receipt)).equal('true');
      });

      it('coupon u3 was used', async () => {
        let used = await checkCouponUsed(client, 'u3');
        expect(used).equal(true);
      });

      it('cannot use coupon u3 again', async () => {
        let receipt = await useCoupon(client, couponCreator, 'u3');
        expect(receipt.success).equal(false);
      });
    });
  });

  after(async () => {
    await provider.close();
  });
});
