const storyService = require('../../src/services/storyService');

describe('StoryService - _extractAmountFromText', () => {
    
    test('Nên trích xu?t dúng don v? "k"', () => {
        const cases = [
            { input: "An ph? h?t 65k", expected: 65000 },
            { input: "Cafe sáng 30K", expected: 30000 },
            { input: "N?p th? 50 k", expected: 50000 }
        ];
        cases.forEach(c => {
            expect(storyService._extractAmountFromText(c.input)).toBe(c.expected);
        });
    });

    test('Nên trích xu?t dúng don v? "tri?u/tr/c?/trieu/cu"', () => {
        const cases = [
            { input: "Mua iPhone 15tr", expected: 15000000 },
            { input: "Ðóng ti?n nhà 5 tri?u", expected: 5000000 },
            { input: "Con xe này 20 c?", expected: 20000000 },
            { input: "Cái này 2 trieu", expected: 20000000 } // FIXME: 2 tri?u
        ];
        // Ðã s?a l?i case test cu?i cho dúng logic
        cases[3].expected = 2000000;
        cases.forEach(c => {
            expect(storyService._extractAmountFromText(c.input)).toBe(c.expected);
        });
    });

test('Nên trích xu?t dúng don v? "lít"', () => {
        const cases = [
            { input: "Nh?u h?t 5 lít", expected: 500000 },
            { input: "Ð? xang 1.5 lit", expected: 150000 }
        ];
        cases.forEach(c => {
            expect(storyService._extractAmountFromText(c.input)).toBe(c.expected);
        });
    });

    test('Nên x? lý du?c s? th?p phân', () => {
        expect(storyService._extractAmountFromText("Ti?n m?ng 0.5tr")).toBe(500000);
        expect(storyService._extractAmountFromText("Ly trà s?a 55.5k")).toBe(55500);
    });

    test('Nên tr? v? null n?u không tìm th?y s? ti?n', () => {
        const cases = ["Hôm nay tr?i d?p quá", "Ði choi v?i g?u", "Không có ti?n"];
        cases.forEach(input => {
            expect(storyService._extractAmountFromText(input)).toBeNull();
        });
    });

    test('Nên uu tiên s? ti?n d?u tiên tìm th?y', () => {
        // Gi? s? user chat: "An 50k, g?i xe 5k" -> Hi?n t?i Regex l?y s? d?u
        expect(storyService._extractAmountFromText("An 50k g?i xe 5k")).toBe(50000);
    });
});
