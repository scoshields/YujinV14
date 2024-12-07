import { create } from 'zustand';
import { supabase } from '../lib/supabase';

interface PartnerStats {
  totalWorkouts: number;
  completedWorkouts: number;
  totalWeight: number;
  completionRate: number;
  name: string;
  username: string;
  workouts: any[];
}

interface PartnerStore {
  stats: Record<string, PartnerStats>;
  isLoading: boolean;
  error: string | null;
  loadPartnerStats: (partnerId: string) => Promise<void>;
  clearStats: () => void;
}

export const usePartnerStore = create<PartnerStore>((set, get) => ({
  stats: {},
  isLoading: false,
  error: null,
  loadPartnerStats: async (partnerId: string) => {
    try {
      set({ isLoading: true, error: null });

      // Get partner info
      const { data: partnerInfo, error: partnerError } = await supabase
        .from('users')
        .select('name, username')
        .eq('id', partnerId)
        .single();

      if (partnerError) throw partnerError;

      // Get partner stats
      const { data, error } = await supabase
        .rpc('get_partner_stats', { partner_id: partnerId });

      if (error) throw error;

      const stats = data?.[0] || {
        total_workouts: 0,
        completed_workouts: 0,
        total_weight: 0,
        completion_rate: 0
      };

      // Get partner's workouts
      const { data: workouts } = await supabase
        .from('daily_workouts')
        .select(`
          id,
          title,
          date,
          duration,
          difficulty,
          completed,
          workout_exercises (
            id,
            name,
            target_sets,
            target_reps,
            exercise_sets (
              id,
              weight,
              reps,
              completed
            )
          )
        `)
        .eq('user_id', partnerId)
        .gte('date', new Date(new Date().getTime() - 7 * 24 * 60 * 60 * 1000).toISOString())
        .order('date', { ascending: false });

      set(state => ({
        stats: {
          ...state.stats,
          [partnerId]: {
            name: partnerInfo.name,
            username: partnerInfo.username,
            totalWorkouts: Number(stats.total_workouts),
            completedWorkouts: Number(stats.completed_workouts),
            totalWeight: Number(stats.total_weight),
            completionRate: Number(stats.completion_rate),
            workouts: workouts || []
          }
        }
      }));

    } catch (err) {
      console.error('Failed to load partner stats:', err);
      set({ error: err instanceof Error ? err.message : 'Failed to load partner stats' });
    } finally {
      set({ isLoading: false });
    }
  },
  clearStats: () => set({ stats: {}, error: null })
}));