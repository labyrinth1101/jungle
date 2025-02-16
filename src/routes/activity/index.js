import { getRecentActivity } from "$queries/transactions";

export async function GET({ request: { headers }, locals }) {
  let { q } = locals;

  try {
    let { recentactivity: transactions } = await q(getRecentActivity(80));
    return { body: { transactions } };
  } catch (e) {
    console.log(e);
    return {
      body: {},
      status: 500,
    };
  }
}
