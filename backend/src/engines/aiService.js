const Groq = require('groq-sdk');

// Check if Groq API key is present
const apiKey = process.env.GROQ_API_KEY;
let groqClient = null;

if (apiKey) {
    try {
        groqClient = new Groq({ apiKey });
        console.log('✅ Groq AI Engine initialized successfully');
    } catch (err) {
        console.error('❌ Failed to initialize Groq AI Client:', err.message);
    }
} else {
    console.warn('⚠️ GROQ_API_KEY not found in environment. AI features will run in Fallback Mode.');
}

const AIService = {
    // We use llama-3.3-70b-versatile as it is fast, highly accurate, and supports json mode.
    // Llama-3-8b-8192 is used as a lightweight alternative.
    MODEL_NAME: 'llama-3.3-70b-versatile',

    /**
     * Parse raw voice text/commands into structured transaction properties.
     * @param {string} text - Voice transcription (e.g., "Spent 300 rupees on lunch at canteen")
     * @returns {Promise<{amount: number, type: 'income'|'expense', category: string, merchant_or_sender: string, note: string|null}>}
     */
    async parseVoice(text) {
        if (!text) throw new Error('Text prompt is required');

        if (!groqClient) {
            return this._mockVoiceFallback(text);
        }

        const prompt = `
            You are BudgetBuddy's AI voice parser. Convert the description of a financial transaction into structured JSON.
            Input Text: "${text}"

            Extract:
            - amount: a positive number.
            - type: "expense" if money is spent/paid/debited, "income" if money is received/credited/earned.
            - category: choose the best from: 'Food & Dining', 'Transport', 'Shopping', 'Education', 'Entertainment', 'Health', 'Utilities', 'Friends/Family', 'Savings/Transfer', or 'Uncategorized'.
            - merchant_or_sender: name of shop, company, or person. If not specified, use "Unknown".
            - note: any additional details, or null if none.

            Output must be ONLY a valid JSON object matching this schema:
            {
                "amount": number,
                "type": "expense" | "income",
                "category": "string",
                "merchant_or_sender": "string",
                "note": "string" or null
            }
        `;

        try {
            const chatCompletion = await groqClient.chat.completions.create({
                messages: [
                    { role: 'user', content: prompt }
                ],
                model: this.MODEL_NAME,
                response_format: { type: 'json_object' }
            });

            const responseText = chatCompletion.choices[0].message.content.trim();
            return JSON.parse(responseText);
        } catch (err) {
            console.error('Groq Voice Parse Error:', err.message);
            return this._mockVoiceFallback(text);
        }
    },

    /**
     * Natural Language Financial Chat Assistant using user's transaction history.
     * @param {string} query - User's question
     * @param {Array} transactions - List of transactions for context
     * @returns {Promise<string>}
     */
    async chat(query, transactions) {
        if (!groqClient) {
            return "⚠️ Groq API key is missing. I'm currently running in offline mode and cannot analyze your transactions dynamically.";
        }

        // Format transactions to a clean text list for context
        const formattedTx = transactions.map(t => 
            `- Date: ${new Date(t.transaction_date).toISOString().split('T')[0]}, Type: ${t.type}, Amount: ₹${t.amount}, Merchant: ${t.merchant_or_sender}, Category: ${t.category}, Note: ${t.note || ''}`
        ).join('\n');

        const systemMessage = `
            You are "BudgetBuddy Assistant", a friendly, smart financial helper.
            You have access to the user's transaction history for the current month.
            Use this data to answer their questions accurately.

            Rules:
            1. Base your figures and insights strictly on the provided transaction history.
            2. Be concise, polite, and helpful.
            3. Highlight key amounts using the ₹ symbol.
            4. If the user asks about something unrelated to their budget or finances, gently steer them back to BudgetBuddy topics.
        `;

        const userPrompt = `
            User Question: "${query}"

            User's Transaction History:
            ${formattedTx || 'No transactions logged this month.'}
        `;

        try {
            const chatCompletion = await groqClient.chat.completions.create({
                messages: [
                    { role: 'system', content: systemMessage },
                    { role: 'user', content: userPrompt }
                ],
                model: this.MODEL_NAME,
            });

            return chatCompletion.choices[0].message.content.trim();
        } catch (err) {
            console.error('Groq Chat Error:', err.message);
            return "Sorry, I encountered an issue analyzing your transactions. Please try again in a moment.";
        }
    },

    /**
     * Fallback categorization for unknown merchants.
     * @param {string} merchantName
     * @returns {Promise<string>}
     */
    async categorizeFallback(merchantName) {
        if (!groqClient) return 'Uncategorized';

        const prompt = `
            Categorize this merchant or transaction sender name: "${merchantName}".
            Choose EXACTLY one of these categories:
            'Food & Dining', 'Transport', 'Shopping', 'Education', 'Entertainment', 'Health', 'Utilities', 'Friends/Family', 'Savings/Transfer', 'Uncategorized'.

            Return only the category name string, no other text or explanation. Do not use JSON.
        `;

        try {
            const chatCompletion = await groqClient.chat.completions.create({
                messages: [
                    { role: 'user', content: prompt }
                ],
                model: this.MODEL_NAME,
                temperature: 0.1
            });

            const category = chatCompletion.choices[0].message.content.trim();
            const validCategories = [
                'Food & Dining', 'Transport', 'Shopping', 'Education', 'Entertainment',
                'Health', 'Utilities', 'Friends/Family', 'Savings/Transfer', 'Uncategorized'
            ];
            return validCategories.includes(category) ? category : 'Uncategorized';
        } catch (err) {
            console.error('Groq Categorization Fallback Error:', err.message);
            return 'Uncategorized';
        }
    },

    /**
     * Staged OCR/Receipt parser structure for future use.
     * Accepts a base64 image or text content.
     */
    async parseReceipt(base64Image) {
        // Groq does not support multimodal vision standard models in all tier pools,
        // so we parse transaction properties from text parsed by local OCR clients.
        if (!groqClient) {
            return {
                amount: 120.00,
                type: 'expense',
                merchant_or_sender: 'Mock Store',
                category: 'Shopping',
                note: 'Parsed from mock receipt'
            };
        }

        const prompt = `
            Analyze this raw OCR text block from a receipt. Extract:
            1. Total Amount paid
            2. Merchant Name
            3. Best category ('Food & Dining', 'Shopping', etc.)
            4. Date of transaction (if readable, formatted as YYYY-MM-DD)

            Return output strictly as a JSON object:
            {
                "amount": number,
                "merchant_or_sender": "string",
                "category": "string",
                "date": "string or null"
            }
        `;

        try {
            const chatCompletion = await groqClient.chat.completions.create({
                messages: [
                    { role: 'user', content: prompt }
                ],
                model: this.MODEL_NAME,
                response_format: { type: 'json_object' }
            });

            const responseText = chatCompletion.choices[0].message.content.trim();
            return JSON.parse(responseText);
        } catch (err) {
            console.error('Groq OCR Parse Error:', err.message);
            throw err;
        }
    },

    // ─── Local Mock Fallbacks (Offline Mode) ────────────────────────────────
    _mockVoiceFallback(text) {
        const lower = text.toLowerCase();
        let amount = 0;
        const amountMatch = lower.match(/(?:rs\.?|inr|₹)?\s*(\d+(?:\.\d{1,2})?)/);
        if (amountMatch) {
            amount = parseFloat(amountMatch[1]);
        }

        let type = 'expense';
        if (lower.includes('received') || lower.includes('credited') || lower.includes('salary') || lower.includes('income')) {
            type = 'income';
        }

        let category = 'Uncategorized';
        let merchant = 'Unknown';

        if (lower.includes('food') || lower.includes('lunch') || lower.includes('dinner') || lower.includes('canteen') || lower.includes('zomato')) {
            category = 'Food & Dining';
            merchant = lower.includes('zomato') ? 'Zomato' : (lower.includes('canteen') ? 'Canteen' : 'Food Vendor');
        } else if (lower.includes('uber') || lower.includes('ola') || lower.includes('auto') || lower.includes('cab')) {
            category = 'Transport';
            merchant = lower.includes('uber') ? 'Uber' : (lower.includes('ola') ? 'Ola' : 'Transport');
        } else if (lower.includes('salary') || lower.includes('pocket money')) {
            category = 'Savings/Transfer';
            merchant = lower.includes('salary') ? 'Employer' : 'Dad/Mom';
        }

        return {
            amount,
            type,
            category,
            merchant_or_sender: merchant,
            note: `Parsed offline: "${text}"`
        };
    }
};

module.exports = AIService;
