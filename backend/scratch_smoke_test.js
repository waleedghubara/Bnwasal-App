const { assertOrderStatusTransition, assertShipmentStatusTransition } = require('./utils/statusTransitions');

function runVerification() {
  console.log('🧪 Running Verification Tests (Negative Tests + Happy Path)...\n');

  // 1. Negative Test: Assigned To Captain -> Delivered
  let assignedToDeliveredBlocked = false;
  try {
    assertOrderStatusTransition('captain', { status: 'Assigned To Captain', captainId: 10 }, 'Delivered', 10);
  } catch (e) {
    assignedToDeliveredBlocked = true;
    console.log(`✅ Negative Test 1: Assigned To Captain ➡️ Delivered is BLOCKED: "${e.message}"`);
  }
  if (!assignedToDeliveredBlocked) {
    console.error('❌ Negative Test 1 FAILED: Jump to Delivered was allowed!');
    process.exit(1);
  }

  // 2. Negative Test: Assigned To Captain -> Completed
  let assignedToCompletedBlocked = false;
  try {
    assertOrderStatusTransition('captain', { status: 'Assigned To Captain', captainId: 10 }, 'Completed', 10);
  } catch (e) {
    assignedToCompletedBlocked = true;
    console.log(`✅ Negative Test 2: Assigned To Captain ➡️ Completed is BLOCKED: "${e.message}"`);
  }
  if (!assignedToCompletedBlocked) {
    console.error('❌ Negative Test 2 FAILED: Jump to Completed was allowed!');
    process.exit(1);
  }

  // 3. Happy Path Sequence: Assigned -> Captain Arrived -> Picked Up -> In Transit -> Delivered -> Completed
  const happyPathSteps = [
    { from: 'Assigned To Captain', to: 'Captain Arrived', role: 'captain', userId: 10 },
    { from: 'Captain Arrived', to: 'Picked Up', role: 'captain', userId: 10 },
    { from: 'Picked Up', to: 'In Transit', role: 'captain', userId: 10 },
    { from: 'In Transit', to: 'Delivered', role: 'captain', userId: 10 },
    { from: 'Delivered', to: 'Completed', role: 'admin', userId: 1 },
  ];

  for (let i = 0; i < happyPathSteps.length; i++) {
    const step = happyPathSteps[i];
    try {
      assertOrderStatusTransition(step.role, { status: step.from, captainId: 10 }, step.to, step.userId);
      console.log(`✅ Happy Path Step ${i + 1}: ${step.from} ➡️ ${step.to} (${step.role}) PASSED`);
    } catch (e) {
      console.error(`❌ Happy Path Step ${i + 1} FAILED:`, e.message);
      process.exit(1);
    }
  }

  console.log('\n🎉 ALL NEGATIVE TESTS AND HAPPY PATH VERIFICATIONS PASSED 100% PERFECTLY!');
  process.exit(0);
}

runVerification();
