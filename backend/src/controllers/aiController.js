const AIService = require('../engines/aiService');

const AIController = {
    /**
     * POST /api/ai/chat
     * Body: { query: "How much did I spend on Food this month?", transactions: [...] }
     */
    async chat(req, res) {
        try {
            const { query, transactions } = req.body;
            if (!query) {
                return res.status(400).json({ success: false, message: 'query parameter is required' });
            }

            // Generate answer using provided transactions context
            const reply = await AIService.chat(query, transactions || []);

            res.json({
                success: true,
                reply
            });
        } catch (err) {
            console.error('AI Chat Controller Error:', err.message);
            res.status(500).json({ success: false, message: 'AI chat assistant failed' });
        }
    },

    /**
     * POST /api/ai/voice-parse
     * Body: { text: "spent 300 on canteen food" }
     */
    async parseVoice(req, res) {
        try {
            const { text } = req.body;
            if (!text) {
                return res.status(400).json({ success: false, message: 'text parameter is required' });
            }

            const parsed = await AIService.parseVoice(text);

            res.json({
                success: true,
                parsed
            });
        } catch (err) {
            console.error('AI Voice Parse Controller Error:', err.message);
            res.status(500).json({ success: false, message: 'AI voice parsing failed' });
        }
    },

    /**
     * POST /api/ai/ocr-upload
     * Body: { image_base64: "..." }
     */
    async parseReceipt(req, res) {
        try {
            const { image_base64 } = req.body;
            if (!image_base64) {
                return res.status(400).json({ success: false, message: 'image_base64 parameter is required' });
            }

            const parsed = await AIService.parseReceipt(image_base64);

            res.json({
                success: true,
                parsed
            });
        } catch (err) {
            console.error('AI OCR Parser Controller Error:', err.message);
            res.status(500).json({ success: false, message: 'AI receipt OCR parsing failed' });
        }
    }
};

module.exports = AIController;
