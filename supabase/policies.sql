-- Users policies
CREATE POLICY "Enable insert for new users" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Enable read access for all users" ON users
  FOR SELECT USING (true);

CREATE POLICY "Enable update for own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Workout partners policies
CREATE POLICY "Enable insert for partners" ON workout_partners
  FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

CREATE POLICY "Enable read access for partners" ON workout_partners
  FOR SELECT USING (
    auth.uid()::uuid = user_id OR 
    auth.uid()::uuid = partner_id
  );

CREATE POLICY "Enable update for partners" ON workout_partners
  FOR UPDATE USING (
    auth.uid()::uuid = user_id OR 
    auth.uid()::uuid = partner_id
  );

CREATE POLICY "Enable delete for partners" ON workout_partners
  FOR DELETE USING (auth.uid()::uuid = user_id);

-- Daily workouts policies
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

CREATE POLICY "Enable insert for workouts" ON daily_workouts
  FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

CREATE POLICY "Enable update for workouts" ON daily_workouts
  FOR UPDATE USING (auth.uid()::uuid = user_id);

CREATE POLICY "Enable delete for workouts" ON daily_workouts
  FOR DELETE USING (auth.uid()::uuid = user_id);

-- Workout exercises policies
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

CREATE POLICY "Enable insert for exercises" ON workout_exercises
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM daily_workouts d
      WHERE d.id = daily_workout_id
      AND d.user_id = auth.uid()::uuid
    )
  );

CREATE POLICY "Enable update for exercises" ON workout_exercises
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM daily_workouts d
      WHERE d.id = daily_workout_id
      AND d.user_id = auth.uid()::uuid
    )
  );

CREATE POLICY "Enable delete for exercises" ON workout_exercises
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM daily_workouts d
      WHERE d.id = daily_workout_id
      AND d.user_id = auth.uid()::uuid
    )
  );

-- Exercise sets policies
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

CREATE POLICY "Enable insert for sets" ON exercise_sets
  FOR INSERT WITH CHECK (auth.uid()::uuid = user_id);

CREATE POLICY "Enable update for sets" ON exercise_sets
  FOR UPDATE USING (auth.uid()::uuid = user_id);

CREATE POLICY "Enable delete for sets" ON exercise_sets
  FOR DELETE USING (auth.uid()::uuid = user_id);

-- Available exercises policies
CREATE POLICY "Enable read access for available exercises" ON available_exercises
  FOR SELECT USING (true);

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE available_exercises ENABLE ROW LEVEL SECURITY;