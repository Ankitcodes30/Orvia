import assert from 'node:assert/strict';
import { moderateReview } from '../src/lib/services/moderation.js';
import {
	allReviews,
	publicApprovedReviews,
	publicRatingSummary,
	submitReview,
	approveReview,
	rejectReview,
	hideReview,
	restoreReview,
	deleteReview,
	permanentlyDeleteReview,
	generateUUID
} from '../src/lib/services/reviewStore.js';
import {
	notificationLogs,
	notifyOwnerOfNewReview,
	clearNotificationLogs
} from '../src/lib/services/notifications.js';
import { isOwnerEmail, OWNER_EMAILS } from '../src/lib/services/auth.js';

let passedTests = 0;
let totalTests = 0;

async function test(description, fn) {
	totalTests++;
	try {
		await fn();
		passedTests++;
		console.log(`  ✓ ${description}`);
	} catch (err) {
		console.error(`  ✗ ${description}`);
		console.error(err);
		process.exitCode = 1;
	}
}

async function runSuite() {
	console.log('\n--- ORVIA RATINGS, MODERATION, PRIVACY & ADMIN TEST SUITE ---\n');

	// 1. MODERATION TESTS
	console.log('1. Automated Moderation Engine:');

	await test('auto-approves genuine positive review', () => {
		const res = moderateReview({
			title: 'Wonderful local player',
			text: 'The dark atmosphere and responsive album art transitions feel incredible. Best music player I have used in years.',
			rating: 5,
			userId: 'usr-1'
		});
		assert.equal(res.status, 'approved');
		assert.equal(res.autoApproved, true);
		assert.equal(res.score, 0);
		assert.equal(res.reasons.length, 0);
	});

	await test('auto-approves genuine negative review (does NOT reject genuine criticism)', () => {
		const res = moderateReview({
			title: 'Contrast issues outdoors',
			text: 'The font contrast in the playlist header is too low in direct sunlight. Needs higher contrast options or a brightness boost.',
			rating: 2,
			userId: 'usr-2'
		});
		// MUST be approved because it is genuine user criticism without abuse or spam!
		assert.equal(res.status, 'approved');
		assert.equal(res.autoApproved, true);
		assert.equal(res.score, 0);
	});

	await test('flags link spam containing external URLs or telegram links', () => {
		const res = moderateReview({
			title: 'Free downloads here',
			text: 'Check out https://spam-crypto.xyz/free for cracked songs or contact t.me/freecrypto now!',
			rating: 5,
			userId: 'usr-spammer'
		});
		assert.equal(res.status, 'flagged');
		assert.equal(res.autoApproved, false);
		assert.ok(res.reasons.includes('unauthorized_external_link'));
		assert.ok(res.score >= 50);
	});

	await test('flags abusive and toxic profanity', () => {
		const res = moderateReview({
			title: 'Stupid app',
			text: 'This stupid idiot developer made pure trash and cheat software.',
			rating: 1,
			userId: 'usr-toxic'
		});
		assert.equal(res.status, 'flagged');
		assert.equal(res.autoApproved, false);
		assert.ok(res.reasons.includes('toxic_or_abusive_language'));
	});

	await test('quarantines excessive character repetition spam', () => {
		const res = moderateReview({
			title: 'Test',
			text: 'Goooooooooooooooood apppppppppppppppp so cooooooooooooooool!!!!!!!!!!!!!!!!',
			rating: 5,
			userId: 'usr-repetitive'
		});
		assert.ok(res.reasons.includes('excessive_character_repetition'));
		assert.ok(res.score >= 25);
		assert.notEqual(res.status, 'approved');
	});

	await test('flags duplicate review submissions', () => {
		const existing = [
			{ id: 'uuid-1', text: 'This is the exact same copy-pasted promotional sentence.' }
		];
		const res = moderateReview(
			{
				id: 'uuid-2',
				title: 'Promo',
				text: 'This is the exact same copy-pasted promotional sentence.',
				rating: 5,
				userId: 'usr-bot'
			},
			existing
		);
		assert.ok(res.reasons.includes('duplicate_review_content'));
		assert.equal(res.status, 'flagged');
	});

	// 2. PRIVACY & DATA INTEGRITY TESTS
	console.log('\n2. Privacy, UUIDs, & Public Projections:');

	await test('generateUUID creates valid standard v4 UUID', () => {
		const id = generateUUID();
		assert.match(
			id,
			/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
		);
	});

	await test('userEmail is strictly excluded from publicApprovedReviews derived store', () => {
		allReviews.set([
			{
				id: 'uuid-pub-1',
				userId: 'usr-google-1',
				userName: 'Alice Listener',
				userEmail: 'alice.private@gmail.com', // PRIVATE!
				userAvatar: 'https://example.com/avatar.jpg',
				rating: 5,
				title: 'Brilliant',
				text: 'Love the minimalist interface.',
				status: 'approved',
				isDeleted: false,
				isHidden: false,
				createdAt: new Date().toISOString()
			}
		]);

		let pubList;
		const unsub = publicApprovedReviews.subscribe((val) => {
			pubList = val;
		});
		unsub();

		assert.equal(pubList.length, 1);
		assert.equal(pubList[0].userName, 'Alice Listener');
		assert.equal(pubList[0].userEmail, undefined, 'userEmail must NEVER be in publicApprovedReviews');
		assert.ok(!('userEmail' in pubList[0]), 'userEmail key must not exist on public review object');
	});

	// 3. RATINGS CALCULATION & QUARANTINE TESTS
	console.log('\n3. Ratings Calculation & Moderation Quarantine:');

	await test('quarantined (pending, flagged, rejected, hidden, deleted) reviews NEVER contribute to public average or count', () => {
		allReviews.set([
			// Approved review
			{
				id: 'uuid-app-1',
				userId: 'usr-1',
				userName: 'User 1',
				userEmail: 'u1@test.com',
				rating: 4,
				status: 'approved',
				isDeleted: false,
				isHidden: false,
				createdAt: new Date().toISOString()
			},
			// Pending review (must be excluded)
			{
				id: 'uuid-pend-1',
				userId: 'usr-2',
				userName: 'User 2',
				userEmail: 'u2@test.com',
				rating: 1,
				status: 'pending',
				isDeleted: false,
				isHidden: false,
				createdAt: new Date().toISOString()
			},
			// Flagged review (must be excluded)
			{
				id: 'uuid-flag-1',
				userId: 'usr-3',
				userName: 'User 3',
				userEmail: 'u3@test.com',
				rating: 5,
				status: 'flagged',
				isDeleted: false,
				isHidden: false,
				createdAt: new Date().toISOString()
			},
			// Rejected review (must be excluded)
			{
				id: 'uuid-rej-1',
				userId: 'usr-4',
				userName: 'User 4',
				userEmail: 'u4@test.com',
				rating: 1,
				status: 'rejected',
				isDeleted: false,
				isHidden: false,
				createdAt: new Date().toISOString()
			},
			// Hidden review (must be excluded)
			{
				id: 'uuid-hid-1',
				userId: 'usr-5',
				userName: 'User 5',
				userEmail: 'u5@test.com',
				rating: 5,
				status: 'approved',
				isDeleted: false,
				isHidden: true, // Hidden by admin
				createdAt: new Date().toISOString()
			},
			// Deleted review (must be excluded)
			{
				id: 'uuid-del-1',
				userId: 'usr-6',
				userName: 'User 6',
				userEmail: 'u6@test.com',
				rating: 5,
				status: 'approved',
				isDeleted: true, // Deleted
				isHidden: false,
				createdAt: new Date().toISOString()
			}
		]);

		let summary;
		const unsub = publicRatingSummary.subscribe((s) => {
			summary = s;
		});
		unsub();

		assert.equal(summary.count, 1, 'Only genuine approved non-hidden review should be counted');
		assert.equal(summary.average, 4.0, 'Average must be exactly 4.0');
		assert.equal(summary.breakdown[4], 1);
		assert.equal(summary.breakdown[5], 0);
		assert.equal(summary.breakdown[1], 0);
	});

	await test('public average rating calculates exact weighted average across approved reviews', () => {
		allReviews.set([
			{
				id: 'uuid-1',
				userId: 'usr-1',
				userName: 'U1',
				rating: 5,
				status: 'approved',
				isDeleted: false,
				isHidden: false,
				createdAt: new Date().toISOString()
			},
			{
				id: 'uuid-2',
				userId: 'usr-2',
				userName: 'U2',
				rating: 4,
				status: 'approved',
				isDeleted: false,
				isHidden: false,
				createdAt: new Date().toISOString()
			},
			{
				id: 'uuid-3',
				userId: 'usr-3',
				userName: 'U3',
				rating: 2,
				status: 'approved',
				isDeleted: false,
				isHidden: false,
				createdAt: new Date().toISOString()
			}
		]);

		let summary;
		const unsub = publicRatingSummary.subscribe((s) => {
			summary = s;
		});
		unsub();

		// (5 + 4 + 2) / 3 = 11 / 3 = 3.666... => 3.7
		assert.equal(summary.count, 3);
		assert.equal(summary.average, 3.7);
		assert.equal(summary.breakdown[5], 1);
		assert.equal(summary.breakdown[4], 1);
		assert.equal(summary.breakdown[2], 1);
	});

	// 4. DUPLICATE ACCOUNT SUBMISSION & EDIT IN PLACE
	console.log('\n4. Duplicate Account Prevention & In-Place Editing:');

	await test('submitting a second review from the same account updates existing review without duplicating', async () => {
		allReviews.set([]);

		// Initial submission
		const rev1 = await submitReview({
			user: { id: 'usr-google-999', name: 'John Doe', email: 'john@example.com' },
			rating: 4,
			title: 'Good initial release',
			text: 'Runs smoothly on Windows 11.',
			platform: 'Windows'
		});

		let list;
		allReviews.subscribe((l) => (list = l))();
		assert.equal(list.length, 1);
		assert.equal(list[0].id, rev1.id);
		assert.equal(list[0].rating, 4);

		// User later edits their review to 5 stars
		const rev2 = await submitReview({
			user: { id: 'usr-google-999', name: 'John Doe', email: 'john@example.com' },
			rating: 5,
			title: 'Updated: absolutely love it now',
			text: 'After testing with FLAC audio files, the playback quality is unmatched.',
			platform: 'Windows'
		});

		allReviews.subscribe((l) => (list = l))();
		assert.equal(list.length, 1, 'Review list length must remain 1 (no duplicate active reviews)');
		assert.equal(list[0].id, rev1.id, 'UUID primary key must remain identical');
		assert.equal(list[0].rating, 5, 'Rating must update to 5');
		assert.equal(list[0].isEdited, true, 'isEdited flag must be true');
	});

	// 5. OWNER ADMIN CONTROLS
	console.log('\n5. Owner Admin Moderation Controls:');

	await test('owner admin can approve, reject, hide, restore, and delete reviews', async () => {
		allReviews.set([]);
		const rev = await submitReview({
			user: { id: 'usr-test-mod', name: 'Test Submitter', email: 'mod@example.com' },
			rating: 3,
			title: 'Decent',
			text: 'Testing admin action lifecycle.',
			platform: 'Android'
		});

		function getRev() {
			let l;
			allReviews.subscribe((val) => (l = val))();
			return l.find((r) => r.id === rev.id);
		}

		// 1. Hide review
		hideReview(rev.id);
		assert.equal(getRev().isHidden, true);

		// 2. Restore review
		restoreReview(rev.id);
		assert.equal(getRev().isHidden, false);

		// 3. Reject review
		rejectReview(rev.id, 'Violates guidelines');
		assert.equal(getRev().status, 'rejected');

		// 4. Approve review
		approveReview(rev.id);
		assert.equal(getRev().status, 'approved');

		// 5. Soft Delete review
		deleteReview(rev.id);
		assert.equal(getRev().isDeleted, true);

		// 6. Permanently Delete
		permanentlyDeleteReview(rev.id);
		assert.equal(getRev(), undefined, 'Permanently deleted review must be removed from store');
	});

	// 6. OWNER NOTIFICATIONS & AUTHORIZATION
	console.log('\n6. Owner Notifications & Authorization:');

	await test('owner email authorization check correctly verifies owner email', () => {
		assert.equal(isOwnerEmail('ankitkumbhare301@gmail.com'), true);
		assert.equal(isOwnerEmail('ANKITKUMBHARE301@GMAIL.COM'), true);
		assert.equal(isOwnerEmail('random@gmail.com'), false);
		assert.equal(isOwnerEmail(null), false);
	});

	await test('owner notification logs submission with review metadata', async () => {
		clearNotificationLogs();
		const rev = {
			id: 'rev-uuid-notif-1',
			userName: 'Dev Tester',
			userEmail: 'dev.tester@gmail.com',
			rating: 5,
			title: 'Excellent',
			text: 'Testing notifications dispatch pipeline.',
			status: 'approved',
			moderationReasons: []
		};

		await notifyOwnerOfNewReview(rev);

		let logs;
		notificationLogs.subscribe((l) => (logs = l))();
		assert.equal(logs.length, 1);
		assert.equal(logs[0].reviewId, rev.id);
		assert.equal(logs[0].reviewer, 'Dev Tester');
		assert.equal(logs[0].rating, 5);
		assert.equal(logs[0].delivered, true);
		assert.equal(logs[0].deliveryMode, 'preview_simulated');
	});

	console.log(`\n========================================`);
	console.log(`TEST SUMMARY: ${passedTests}/${totalTests} tests passed.`);
	console.log(`========================================\n`);

	if (process.exitCode && process.exitCode !== 0) {
		process.exit(process.exitCode);
	}
}

runSuite();
