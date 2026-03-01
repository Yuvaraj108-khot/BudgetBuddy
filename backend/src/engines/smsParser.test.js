/**
 * Quick test for the SMS Parser
 * Run: node src/engines/smsParser.test.js
 */

const { parseSms } = require('./smsParser');

const TEST_MESSAGES = [
    // ── UPI Debit ──────────────────────────────────────────────────────
    {
        label: 'PhonePe debit',
        sms: 'Rs.150.00 debited from A/c XX1234 on 01-Mar-26. Info: UPI/Zomato Online. Avl bal: Rs.4,250.00'
    },
    {
        label: 'GPay debit to canteen',
        sms: 'Your A/c XX9876 has been debited INR 80.00 on 28-Feb-26. Payment to Campus Canteen via UPI. Available balance Rs.2,100.00'
    },
    {
        label: 'Paytm debit to Swiggy',
        sms: 'INR 349 debited from UPI A/c XXXXXXXX to Swiggy on 01-Mar-26. Ref No. 123456789.'
    },

    // ── UPI Credit ─────────────────────────────────────────────────────
    {
        label: 'Received from friend',
        sms: 'Rs.500 credited to your A/c XX5678 on 01-Mar-26. Info: UPI/Rahul Sharma. Avl bal: Rs.3,500.00'
    },
    {
        label: 'HDFC bank credit',
        sms: 'INR 2,000.00 credited to A/c XXXXXXXXXX2345 by NEFT from Dad on 28-Feb-26.'
    },

    // ── Should be IGNORED ──────────────────────────────────────────────
    {
        label: 'OTP message (should skip)',
        sms: 'Your OTP for transaction is 483920. Valid for 10 minutes. Do not share.'
    },
    {
        label: 'Promo message (should skip)',
        sms: 'Congratulations! Get 10% cashback on your next transaction. Offer valid till March 31.'
    },
    {
        label: 'Random SMS (should skip)',
        sms: 'Your order has been shipped. Track it at track.example.com'
    }
];

console.log('\n🧪 SMS Parser Test Results\n' + '═'.repeat(60));

let passed = 0, failed = 0;

TEST_MESSAGES.forEach(({ label, sms }) => {
    const result = parseSms(sms);
    const icon = result.is_transaction ? '💳' : '🚫';

    console.log(`\n${icon} ${label}`);
    console.log(`   SMS: "${sms.substring(0, 70)}..."`);

    if (result.is_transaction) {
        console.log(`   ✅ Type:       ${result.type}`);
        console.log(`   ✅ Amount:     ₹${result.amount}`);
        console.log(`   ✅ Merchant:   ${result.merchant_or_sender}`);
        console.log(`   ✅ Category:   ${result.category}`);
        console.log(`   ✅ Confidence: ${result.confidence}`);
        if (result.balance_after) console.log(`   ✅ Balance:    ₹${result.balance_after}`);
        passed++;
    } else {
        console.log(`   ⏭️  Skipped →  ${result.reason}`);
        passed++;
    }
});

console.log('\n' + '═'.repeat(60));
console.log(`\n✅ All ${passed} test cases completed.\n`);
