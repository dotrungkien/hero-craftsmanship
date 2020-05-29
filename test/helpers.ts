import { Client, Result, Receipt } from '@blockstack/clarity';
import { stringify } from 'querystring';

const couponCreator = 'SP3GHS3JVCBPW4K0HJ95VCKZ6EDWV08YMZ85XQGN0';

function unwrapAddress(result: string) {
  return result.match(/^\(ok\s(\w+)\)$/)[1];
}
async function getTotalCode(client: Client) {
  let query = client.createQuery({
    method: {
      name: 'get-total-code',
      args: [],
    },
  });
  const receipt = await client.submitQuery(query);
  const totalCode = Result.unwrapUInt(receipt);
  return totalCode;
}

async function checkCouponValid(client: Client, couponCode: string) {
  let query = client.createQuery({
    method: {
      name: 'check-coupon-valid',
      args: [couponCode],
    },
  });
  const receipt = await client.submitQuery(query);
  let result = Result.unwrap(receipt);
  return result.includes('true');
}

async function checkCouponUsed(client: Client, couponCode: string) {
  let query = client.createQuery({
    method: {
      name: 'check-coupon-used',
      args: [couponCode],
    },
  });
  const receipt = await client.submitQuery(query);
  let result = Result.unwrap(receipt);
  return result.includes('true');
}

async function checkCouponDiscount(client: Client, couponCode: string) {
  let query = client.createQuery({
    method: {
      name: 'check-coupon-discount',
      args: [couponCode],
    },
  });
  const receipt = await client.submitQuery(query);
  const discount = Result.unwrapUInt(receipt);
  return discount;
}

async function ownerOf(client: Client, couponCode: string) {
  let query = client.createQuery({
    method: {
      name: 'get-owner-of',
      args: [couponCode],
    },
  });
  const receipt = await client.submitQuery(query);
  const owner = unwrapAddress(Result.unwrap(receipt));
  return owner;
}

async function isOwner(client: Client, actor: string, couponCode: string) {
  let query = client.createQuery({
    method: {
      name: 'is-owner',
      args: [`'${actor}`, couponCode],
    },
  });
  const receipt = await client.submitQuery(query);
  return receipt;
}

async function execMethod(
  client: Client,
  signature: string,
  method: string,
  args: string[],
  debug = false
): Promise<Receipt> {
  const tx = client.createTransaction({
    method: {
      name: method,
      args: args,
    },
  });
  await tx.sign(signature);
  const receipt = await client.submitTransaction(tx);
  return receipt;
}

async function createCoupon(client: Client, discount: string) {
  return execMethod(client, couponCreator, 'create-coupon', [discount]);
}

async function useCoupon(
  client: Client,
  signature: string,
  counponCode: string
) {
  return execMethod(client, signature, 'use-coupon', [counponCode], true);
}

async function transferCoupon(
  client: Client,
  signature: string,
  receiver: string,
  counponCode: string
) {
  return execMethod(
    client,
    signature,
    'transfer',
    [`'${receiver}`, counponCode],
    true
  );
}

export {
  unwrapAddress,
  createCoupon,
  getTotalCode,
  checkCouponValid,
  checkCouponDiscount,
  checkCouponUsed,
  transferCoupon,
  ownerOf,
  isOwner,
  useCoupon,
};
