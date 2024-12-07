-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for workouts" ON daily_workouts;
DROP POLICY IF EXISTS "Enable read access for exercises" ON workout_exercises;
DROP POLICY IF EXISTS "Enable read access for sets" ON exercise_sets;

-- Create new policies that properly handle partner access
CREATE POLICY "Enable read access for workouts" ON daily_workouts
  FOR SELECT USING (
    auth.uid()::uuid = user_id OR
    EXISTS (
      SELECT 1 FROM workout_partners wp
      WHERE wp.status = 'accepted'
      AND (
        (wp.user_id = auth.uid()::uuid AND wp.partner_id = daily_workouts.user_id) OR
        (wp.partner_id = auth.uid()::uuid AND wp.user_id = daily_workouts.user_id)
      )
    )
  );

CREATE POLICY "Enable read access for exercises" ON workout_exercises
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM daily_workouts d
      WHERE d.id = daily_workout_id
      AND (
        d.user_id = auth.uid()::uuid OR
        EXISTS (
          SELECT 1 FROM workout_partners wp
          WHERE wp.status = 'accepted'
          AND (
            (wp.user_id = auth.uid()::uuid AND wp.partner_id = d.user_id) OR
            (wp.partner_id = auth.uid()::uuid AND wp.user_id = d.user_id)
          )
        )
      )
    )
  );

CREATE POLICY "Enable read access for sets" ON exercise_sets
  FOR SELECT USING (
    auth.uid()::uuid = user_id OR
    EXISTS (
      SELECT 1 FROM workout_exercises we
      JOIN daily_workouts d ON we.daily_workout_id = d.id
      JOIN workout_partners wp ON wp.status = 'accepted'
      AND (
        (wp.user_id = auth.uid()::uuid AND wp.partner_id = d.user_id) OR
        (wp.partner_id = auth.uid()::uuid AND wp.user_id = d.user_id)
      )
      WHERE we.id = exercise_id
    )
  );