-- Drop existing policies and functions
DROP POLICY IF EXISTS "Enable read access for partners" ON daily_workouts;
DROP POLICY IF EXISTS "Enable read access for exercises" ON workout_exercises;
DROP POLICY IF EXISTS "Enable read access for sets" ON exercise_sets;
DROP FUNCTION IF EXISTS get_partner_stats(UUID);

-- Create simplified partner stats function
CREATE OR REPLACE FUNCTION get_partner_stats(partner_id UUID)
RETURNS TABLE (
  total_workouts INTEGER,
  completed_workouts INTEGER,
  total_weight DECIMAL,
  completion_rate INTEGER
) AS $$
BEGIN
  -- Simple direct query for partner stats
  RETURN QUERY
  WITH workout_stats AS (
    SELECT 
      d.id,
      d.completed,
      COALESCE(SUM(CASE WHEN es.completed AND es.weight > 0 AND es.reps > 0 THEN es.weight ELSE 0 END), 0) as weight
    FROM daily_workouts d
    LEFT JOIN workout_exercises we ON we.daily_workout_id = d.id
    LEFT JOIN exercise_sets es ON es.exercise_id = we.id
    WHERE d.user_id = partner_id
    AND d.date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY d.id, d.completed
  )
  SELECT 
    COUNT(*)::INTEGER,
    COUNT(CASE WHEN completed THEN 1 END)::INTEGER,
    COALESCE(SUM(weight), 0),
    CASE 
      WHEN COUNT(*) > 0 THEN 
        (COUNT(CASE WHEN completed THEN 1 END) * 100 / COUNT(*))::INTEGER
      ELSE 0 
    END
  FROM workout_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_partner_stats(UUID) TO authenticated;

-- Create simplified RLS policies
CREATE POLICY "Enable read access for all" ON daily_workouts
  FOR SELECT USING (true);

CREATE POLICY "Enable read access for all" ON workout_exercises
  FOR SELECT USING (true);

CREATE POLICY "Enable read access for all" ON exercise_sets
  FOR SELECT USING (true);

-- Ensure tables have RLS enabled
ALTER TABLE daily_workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_sets ENABLE ROW LEVEL SECURITY;