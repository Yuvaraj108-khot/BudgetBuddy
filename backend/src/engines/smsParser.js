/**
 * SMS Transaction Parser
 *
 * Parses raw bank/UPI SMS messages to extract:
 * - amount
 * - type (income / expense)
 * - merchant_or_sender
 * - category (guessed from merchant keywords)
 *
 * Supports common Indian bank SMS formats:
 * - UPI (PhonePe, GPay, Paytm, BHIM)
 * - HDFC, SBI, ICICI, Axis, Kotak, Canara, BOB
 * - Debit/Credit card alerts
 */

// ─── Regex Patterns ────────────────────────────────────────────────────────

const PATTERNS = {
    // Match amounts like Rs.500, INR 1,200.50, ₹3000
    amount: /(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)/i,

    // UPI credit (money received)
    upiCredit: /(?:credited|received|credit|deposited)\s+(?:rs\.?|inr|₹)\s*[\d,]+|(?:rs\.?|inr|₹)\s*[\d,]+(?:\.\d{1,2})?\s+(?:credited|received|deposited)/i,

    // UPI debit (money sent)
    upiDebit: /(?:debited|sent|paid|deducted|withdrawn|payment\s+of)\s+(?:rs\.?|inr|₹)\s*[\d,]+|(?:rs\.?|inr|₹)\s*[\d,]+(?:\.\d{1,2})?\s+(?:debited|sent|paid|deducted)/i,

    // UPI merchant — "to <merchant>" or "at <merchant>"
    merchantTo: /(?:to|at|towards|paid\s+to)\s+([A-Za-z0-9 &._\-']{2,40})(?:\s+on|\s+via|\s+ref|\s+upi|\.|$)/i,

    // UPI sender — "from <sender>"
    merchantFrom: /(?:from|by)\s+([A-Za-z0-9 &._\-']{2,40})(?:\s+on|\s+via|\s+ref|\s+upi|\.|$)/i,

    // OTP guard — skip OTP messages entirely
    otp: /\b(otp|one.time.password|verification.code)\b/i,

    // Guard: promotional messages
    promo: /\b(offer|cashback|reward|discount|loyalty|win|congratulations|avail)\b/i,

    // Balance pattern
    balance: /(?:avl\.?\s*bal(?:ance)?|bal(?:ance)?)\s*(?:rs\.?|inr|₹|:)?\s*([\d,]+(?:\.\d{1,2})?)/i
};

// ─── Category Mapping ──────────────────────────────────────────────────────

const CATEGORY_KEYWORDS = {
    'Food & Dining': ['zomato', 'swiggy', 'canteen', 'cafe', 'restaurant', 'food', 'hotel', 'pizza', 'burger', 'dhaba', 'biryani', 'tea', 'mess'],
    'Transport': ['ola', 'uber', 'rapido', 'auto', 'bus', 'metro', 'fuel', 'petrol', 'diesel', 'irctc', 'railway', 'redbus', 'cab'],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'market', 'store', 'mall', 'shop', 'mart', 'bazar', 'retail'],
    'Education': ['college', 'university', 'school', 'course', 'udemy', 'coursera', 'books', 'library', 'fees', 'tuition'],
    'Entertainment': ['netflix', 'hotstar', 'prime', 'spotify', 'youtube', 'movie', 'cinema', 'pvr', 'inox', 'gaming'],
    'Health': ['pharmacy', 'hospital', 'clinic', 'medicine', 'doctor', 'health', 'medical', 'apollo', 'chemist', 'lab'],
    'Utilities': ['electricity', 'water', 'gas', 'internet', 'broadband', 'mobile', 'recharge', 'bill', 'airtel', 'jio', 'vi', 'bsnl'],
    'Friends/Family': ['friend', 'bro', 'sis', 'mom', 'dad', 'family', 'home'],
    'Savings/Transfer': ['savings', 'fd', 'investment', 'mutual', 'transfer', 'neft', 'imps', 'rtgs', 'self']
};

// ─── Helper Functions ──────────────────────────────────────────────────────

function extractAmount(sms) {
    const match = sms.match(PATTERNS.amount);
    if (!match) return null;
    return parseFloat(match[1].replace(/,/g, ''));
}

function extractType(sms) {
    if (PATTERNS.upiCredit.test(sms)) return 'income';
    if (PATTERNS.upiDebit.test(sms)) return 'expense';
    return null;
}

function extractMerchant(sms, type) {
    if (type === 'expense') {
        const m = sms.match(PATTERNS.merchantTo);
        if (m) return m[1].trim().replace(/\s+/g, ' ');
    }
    if (type === 'income') {
        const m = sms.match(PATTERNS.merchantFrom);
        if (m) return m[1].trim().replace(/\s+/g, ' ');
    }
    return 'Unknown';
}

function guessCategory(merchant) {
    if (!merchant || merchant === 'Unknown') return 'Uncategorized';
    const lower = merchant.toLowerCase();
    for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
        if (keywords.some(kw => lower.includes(kw))) return category;
    }
    return 'Uncategorized';
}

function extractBalance(sms) {
    const match = sms.match(PATTERNS.balance);
    if (match) return parseFloat(match[1].replace(/,/g, ''));
    return null;
}

// ─── Main Parser ───────────────────────────────────────────────────────────

/**
 * Parse a raw bank/UPI SMS string.
 *
 * @param {string} rawSms - Raw SMS text
 * @returns {{
 *   is_transaction: boolean,
 *   amount: number|null,
 *   type: string|null,
 *   merchant_or_sender: string,
 *   category: string,
 *   balance_after: number|null,
 *   confidence: 'high'|'medium'|'low',
 *   reason: string
 * }}
 */
function parseSms(rawSms) {
    const sms = rawSms.trim();

    // ── Guard: OTP messages ──
    if (PATTERNS.otp.test(sms)) {
        return { is_transaction: false, reason: 'OTP message — skipped' };
    }

    // ── Guard: Promotional messages ──
    if (PATTERNS.promo.test(sms)) {
        return { is_transaction: false, reason: 'Promotional message — skipped' };
    }

    const amount = extractAmount(sms);
    const type = extractType(sms);

    if (!amount || !type) {
        return {
            is_transaction: false,
            reason: !amount ? 'No amount found' : 'Could not determine income/expense'
        };
    }

    const merchant_or_sender = extractMerchant(sms, type);
    const category = guessCategory(merchant_or_sender);
    const balance_after = extractBalance(sms);

    // Confidence rating
    let confidence = 'high';
    if (merchant_or_sender === 'Unknown') confidence = 'medium';
    if (!type) confidence = 'low';

    return {
        is_transaction: true,
        amount,
        type,
        merchant_or_sender,
        category,
        balance_after,
        confidence,
        reason: 'Parsed successfully'
    };
}

module.exports = { parseSms, guessCategory, extractAmount, extractType };
