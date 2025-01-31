import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Helper function to create content hash
function stringToUint8Array(str: string): Uint8Array
{
    return new Uint8Array([...str].map(char => char.charCodeAt(0)));
}

// Basic Content Functions Tests
Clarinet.test({
    name: "Ensure that basic content submission works",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "submit-content",
                [types.buff(stringToUint8Array("test content hash"))],
                user1.address
            )
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        assertEquals(block.receipts[0].result, '(ok u1)');

        // Verify content exists
        const contentResult = chain.callReadOnlyFn(
            "content-moderation",
            "get-content",
            [types.uint(1)],
            user1.address
        );
        assertEquals(contentResult.result.includes(user1.address), true);
        assertEquals(contentResult.result.includes('"status": "pending"'), true);
    }
});
