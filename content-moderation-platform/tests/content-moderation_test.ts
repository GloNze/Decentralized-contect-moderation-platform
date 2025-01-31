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

// Voting System Tests
Clarinet.test({
    name: "Ensure that voting system works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;
        const user2 = accounts.get("wallet_2")!;

        // First give reputation to voters
        let block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "stake-tokens",
                [types.uint(1000)],
                user2.address
            )
        ]);

        // Submit content
        block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "submit-content",
                [types.buff(stringToUint8Array("test content hash"))],
                user1.address
            )
        ]);

        // Vote on content
        block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "vote",
                [types.uint(1), types.bool(true)],
                user2.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(ok true)');

        // Try to vote again (should fail)
        block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "vote",
                [types.uint(1), types.bool(true)],
                user2.address
            )
        ]);
        assertEquals(block.receipts[0].result, '(err u2)'); // ERR-ALREADY-VOTED
    }
});

// Category System Tests
Clarinet.test({
    name: "Ensure that category system works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;

        // Create category
        let block = chain.mineBlock([
            // First stake tokens to get reputation
            Tx.contractCall(
                "content-moderation",
                "stake-tokens",
                [types.uint(1000)],
                deployer.address
            ),
            Tx.contractCall(
                "content-moderation",
                "create-category",
                [
                    types.ascii("test-category"),
                    types.uint(100),
                    types.uint(2)
                ],
                deployer.address
            )
        ]);

        assertEquals(block.receipts[1].result, '(ok u1)');

        // Submit content with category
        block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "submit-content-with-category",
                [
                    types.buff(stringToUint8Array("test content hash")),
                    types.uint(1)
                ],
                deployer.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(ok u1)');
    }
});


// Appeals System Tests
Clarinet.test({
    name: "Ensure that appeals system works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;
        const user2 = accounts.get("wallet_2")!;

        // Submit content and finalize moderation
        let block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "submit-content",
                [types.buff(stringToUint8Array("test content hash"))],
                user1.address
            )
        ]);

        // Mine blocks to pass voting period
        chain.mineEmptyBlockUntil(150);

        // Finalize moderation
        block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "finalize-moderation",
                [types.uint(1)],
                deployer.address
            )
        ]);

        // Submit appeal
        block = chain.mineBlock([
            Tx.contractCall(
                "content-moderation",
                "appeal-decision",
                [
                    types.uint(1),
                    types.ascii("appeal reason"),
                    types.buff(stringToUint8Array("evidence hash"))
                ],
                user1.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(ok true)');

        // Vote on appeal
        block = chain.mineBlock([
            // First stake to get reputation
            Tx.contractCall(
                "content-moderation",
                "stake-tokens",
                [types.uint(1000)],
                user2.address
            ),
            Tx.contractCall(
                "content-moderation",
                "vote-on-appeal",
                [types.uint(1), types.bool(true)],
                user2.address
            )
        ]);

        assertEquals(block.receipts[1].result, '(ok true)');
    }
});


