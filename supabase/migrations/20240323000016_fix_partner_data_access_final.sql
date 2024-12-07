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
  SELECT 
    COUNT(DISTINCT d.id)::INTEGER,
    COUNT(DISTINCT CASE WHEN d.completed THEN d.id END)::INTEGER,
    COALESCE(SUM(CASE WHEN es.completed AND es.weight > 0 AND es.reps > 0 THEN es.weight ELSE 0 END), 0),
    CASE 
      WHEN COUNT(DISTINCT d.id) > 0 THEN 
        (COUNT(DISTINCT CASE WHEN d.completed THEN d.id END) * 100 / COUNT(DISTINCT d.id))::INTEGER
      ELSE 0 
    END
  FROM daily_workouts d
  LEFT JOIN workout_exercises we ON we.daily_workout_id = d.id
  LEFT JOIN exercise_sets es ON es.exercise_id = we.id
  WHERE d.user_id = partner_id
  AND d.date >= CURRENT_DATE - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_partner_stats(UUID) TO authenticated;

-- Create simplified RLS policies
CREATE POLICY "Enable read access for partners" ON daily_workouts
  FOR ALL USING (true);

CREATE POLICY "Enable read access for exercises" ON workout_exercises
  FOR ALL USING (true);

CREATE POLICY "Enable read access for sets" ON exercise_sets
  FOR ALL USING (true);

-- Ensure tables have RLS enabled
ALTER TABLE daily_workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_sets ENABLE ROW LEVEL SECURITY;